//
//  ExtensionDelegate.swift
//  Stand Minus WatchKit Extension
//
//  Created by 肇鑫 on 2017-1-31.
//  Copyright © 2017年 ParusSoft.com. All rights reserved.
//

import WatchKit
import ClockKit
import UserNotifications
import HealthKit
import WatchConnectivity

class ExtensionDelegate: NSObject, WKExtensionDelegate {
    var session:WCSession!
    func applicationDidFinishLaunching() {
        // Perform any final initialization of your application.
        UNUserNotificationCenter.current().requestAuthorization(options: [.sound, .alert]) { (success, error) in
        }
        
        session = WCSession.default
        session.delegate = self
        session.activate()
    }
    
    deinit {
        StandHourQuery.terminate()
        TodayStandData.terminate()
    }
    
//    private var anchor:HKQueryAnchor? = nil
    var hasComplication:Bool!
//    private var messageType:MessageType!
    private lazy var userNotificationCenterDelegate = UserNotificationCenterDelegate()
    private var semaphore = DispatchSemaphore(value: 1)
    
    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        // Sent when the system needs to launch the application in the background to process tasks. Tasks arrive in a set, so loop through and process each one.
        for task in backgroundTasks {
            // Use a switch statement to check the task type
            switch task {
            case let backgroundTask as WKApplicationRefreshBackgroundTask:
                // Be sure to complete the background task once you’re done.
                let query = StandHourQuery.shared()
//                query.hasComplication = hasComplication
                let resultsHandler:HKSampleQuery.ResultsHandler = { [unowned self] (_, samples, error) in
                    defer {
                        backgroundTask.setTaskCompletedWithSnapshot(false)
                    }
                    
                    if error == nil,
                        let samples = samples,
                        samples.isEmpty {
                        
                        self.notifyUser()
                    }
                }
                
                let predicate:(Date) -> NSPredicate = { (now) -> NSPredicate in
                    let predicate = HKQuery.predicateForSamples(withStart: now, end: nil, options: [])
                    
                    return predicate
                }
                
                query.executeSampleQuery(resultsHandler: resultsHandler, with: predicate)
            case let snapshotTask as WKSnapshotRefreshBackgroundTask:
                // Snapshot tasks have a unique completion call, make sure to set your expiration date
                snapshotTask.setTaskCompleted(restoredDefaultState: false, estimatedSnapshotExpiration: Date.distantFuture, userInfo: nil)
            case let connectivityTask as WKWatchConnectivityRefreshBackgroundTask:
                // Be sure to complete the connectivity task once you’re done.
                connectivityTask.setTaskCompletedWithSnapshot(false)
            case let urlSessionTask as WKURLSessionRefreshBackgroundTask:
                // Be sure to complete the URL session task once you’re done.
                urlSessionTask.setTaskCompletedWithSnapshot(false)
            default:
                // make sure to complete unhandled task types
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }
    
    private func updateComplications() {
        let server = CLKComplicationServer.sharedInstance()
        server.activeComplications!.forEach { server.reloadTimeline(for: $0) }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension ExtensionDelegate:UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert,.sound])
    }
}

// MARK: - WKSessionDelegate
extension ExtensionDelegate:WCSessionDelegate {
    /** Called when the session has completed activation. If session state is WCSessionActivationStateNotActivated there will be an error with more details. */
    @available(watchOS 2.2, *)
    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("watch sessin is ready.")
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
//        let typeRawValue = userInfo["type"] as! String
//        messageType = MessageType(rawValue: typeRawValue)!
        if let hasComplication = userInfo["hasComplication"] as? Bool {
            self.hasComplication = hasComplication
            print("get user info")
        }
        
        let query = StandHourQuery.shared()
//        query.hasComplication = hasComplication
        
//        print(messageType)
        
//        switch messageType! {
//        case .newHour, .rightNow:
        let resultsHandler:HKSampleQuery.ResultsHandler = { [unowned self] (_, samples, error) in
            defer {
                self.semaphore.signal()
            }
            
            if error == nil {
                let todayStandData = TodayStandData.shared()
                
                if let samples = samples as? [HKCategorySample] {
                    todayStandData.samples = samples
                } else {
                    todayStandData.samples = []
                }
//
//                        try? session.updateApplicationContext(["total":todayStandData.total, "hasStoodInCurrentHour":todayStandData.hasStoodInCurrentHour, "date":todayStandData.now])
                
                self.updateComplications()
                
                if todayStandData.total >= 12 && todayStandData.hasStoodInCurrentHour == false {
                    let calendar = Calendar(identifier: .gregorian)
                    var cps = calendar.dateComponents([.year, .month, .day, .hour], from: todayStandData.now)
                    cps.minute = 50
                    let firedate = calendar.date(from: cps)!
                    
                    WKExtension.shared().scheduleBackgroundRefresh(withPreferredDate: firedate, userInfo: nil, scheduledCompletion: { (error) in
                        
                    })
                }
            }
        }
//        case .fiftyMinutes:
//            preResultsHandler = { (now, hasComplication) -> HKSampleQuery.ResultsHandler in
//                return { [unowned self] (_, samples, error) in
//                    defer {
//                        self.semaphore.signal()
//                    }
//
//                    if error == nil {
//                        let todayStandData = TodayStandData.shared()
//
//                        if let samples = samples as? [HKCategorySample] {
//                            todayStandData.samples = samples
//                        } else {
//                            todayStandData.samples = []
//                        }
//
//                        try? session.updateApplicationContext(["total":todayStandData.total, "hasStoodInCurrentHour":todayStandData.hasStoodInCurrentHour, "date":todayStandData.now])
//
//                        if !todayStandData.hasStoodInCurrentHour {
//                            self.notifyUser()
//                        }
//                    }
//                }
//            }
//        }
        
        semaphore.wait()
        
        DispatchQueue.global(qos: .userInteractive).async {
            query.executeSampleQuery(resultsHandler: resultsHandler)
        }
        
        semaphore.wait()
        semaphore.signal()
    }
    
    private func notifyUser() {
        let center = UNUserNotificationCenter.current()
        if center.delegate == nil { center.delegate = userNotificationCenterDelegate }
        center.getNotificationSettings { (notificationSettings) in
            let id = UUID().uuidString
            let content = { () -> UNMutableNotificationContent in
                let mc = UNMutableNotificationContent()
                mc.title = NSLocalizedString("Please Stand Up!", comment: "Stand Up Notification Title")
                mc.body = NSLocalizedString("Is the time to move up about your body!", comment: "Stand Up Notification Body")
                mc.categoryIdentifier = "notify_user_category"
                
                if notificationSettings.soundSetting == .enabled {
                    mc.sound = UNNotificationSound.default()
                }
                
                return mc
            }()
            let request = UNNotificationRequest(identifier: id, content: content, trigger: nil) // nil means call the trigger immediately
            center.add(request, withCompletionHandler: nil)
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
class UserNotificationCenterDelegate:NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert,.sound])
    }
}
