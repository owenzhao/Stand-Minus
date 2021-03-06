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
    var previousModel:ComplicationModel? = nil
    
    private lazy var defaults = UserDefaults.standard
    
    func applicationDidFinishLaunching() {
        // Perform any final initialization of your application.
        UNUserNotificationCenter.current().requestAuthorization(options: [.sound, .alert]) { (success, error) in
        }
        
        session = WCSession.default
        session.delegate = self
        session.activate()
    }
    
    private lazy var userNotificationCenterDelegate = UserNotificationCenterDelegate()
    private var semaphore = DispatchSemaphore(value: 1)
    private lazy var query = StandHourQuery()
    
    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        // Sent when the system needs to launch the application in the background to process tasks. Tasks arrive in a set, so loop through and process each one.
        for task in backgroundTasks {
            // Use a switch statement to check the task type
            switch task {
            case let backgroundTask as WKApplicationRefreshBackgroundTask:
                // Be sure to complete the background task once you’re done.
                
                guard let rawValue = backgroundTask.userInfo as? Int,
                    let backgroundTaskType = BackgroundTaskType(rawValue:rawValue) else {
                        
                    backgroundTask.setTaskCompletedWithSnapshot(false)
                    return
                }
                
                switch backgroundTaskType {
                case .checkNofifyUser:
                    break
                case .requestRemoteNotificationRegister:
                    if session.activationState == .activated && session.isReachable {
                        session.sendMessage([:], replyHandler: nil, errorHandler: nil)
                    }
                    else {
                        WKExtension.shared().scheduleBackgroundRefresh(withPreferredDate: Date().addingTimeInterval(60 * 60), userInfo: BackgroundTaskType.requestRemoteNotificationRegister.rawValue as NSNumber, scheduledCompletion: { (error) in
                            
                        })
                    }
                    
                    // update the complication at the very beginning time of the hour as soon as possible
                    let sessionResultsHandler:HKSampleQuery.ResultsHandler = { [unowned self] (_, samples, error) in
                        defer {
                            backgroundTask.setTaskCompletedWithSnapshot(false)
                        }
                        
                        if error == nil {
                            var standData = StandData()
                            
                            if let samples = samples as? [HKCategorySample] {
                                standData.samples = samples
                            } else {
                                standData.samples = []
                            }
                            
                            self.updateComplications()
                        }
                    }
                    
                    self.query.executeSampleQuery(resultsHandler: sessionResultsHandler)
                }
                
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

//// MARK: - UNUserNotificationCenterDelegate
//extension ExtensionDelegate:UNUserNotificationCenterDelegate {
//    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
//        completionHandler([.alert,.sound])
//    }
//}

// MARK: - WKSessionDelegate
extension ExtensionDelegate:WCSessionDelegate {
    /** Called when the session has completed activation. If session state is WCSessionActivationStateNotActivated there will be an error with more details. */
    @available(watchOS 2.2, *)
    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("watch sessin is ready.")
    }
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        guard let rawValue = userInfo["rawValue"] as? String,
            let messageType = MessageType(rawValue:rawValue) else {
            return
        }
        
        synchronize { [unowned self] in
            switch messageType {
            case .newHour:
                self.removeDeliveredNotificationIfThereIsAny()
                
                let sessionResultsHandler:HKSampleQuery.ResultsHandler = { [unowned self] (_, samples, error) in
                    defer {
                        self.semaphore.signal()
                    }

                    if error == nil {
                        var standData = StandData()

                        if let samples = samples as? [HKCategorySample] {
                            standData.samples = samples
                        } else {
                            standData.samples = []
                        }

                        self.updateComplications()
                    }

                    let firedate = Date().addingTimeInterval(70 * 60)

                    WKExtension.shared().scheduleBackgroundRefresh(withPreferredDate: firedate, userInfo: BackgroundTaskType.requestRemoteNotificationRegister.rawValue as NSNumber, scheduledCompletion: { (error) in

                    })
                }

                self.query.executeSampleQuery(resultsHandler: sessionResultsHandler)
            case .fiftyMinutes:
                let total = self.defaults.integer(forKey: DefaultsKey.total.key)
                
                if total >= 12 {
                    let sessionResultsHandler:HKSampleQuery.ResultsHandler = { [unowned self] (_, samples, error) in
                        defer {
                            self.semaphore.signal()
                        }

                        if error == nil {
                            var standData = StandData()

                            if let samples = samples as? [HKCategorySample] {
                                standData.samples = samples
                            } else {
                                standData.samples = []
                            }
                            
                            if !standData.hasStoodInCurrentHour {
                                let now = Date()
                                let minute = StandHourQuery.calendar.component(.minute, from: now)
                                
                                if (50..<60).contains(minute) {
                                    self.notifyUser()
                                }
                            }
                        }
                    }

                    self.query.executeSampleQuery(resultsHandler: sessionResultsHandler)
                }
                else {
                    self.semaphore.signal()
                }
            default:
                fatalError("should never happens.")
            }
        }
    }
    
    func synchronize(_ closure:@escaping () -> ()) {
        semaphore.wait()
        
        DispatchQueue.global(qos: .userInteractive).async(execute: closure)
        
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
                    mc.sound = UNNotificationSound.default
                }
                
                return mc
            }()
            let request = UNNotificationRequest(identifier: id, content: content, trigger: nil) // nil means call the trigger immediately
            center.add(request, withCompletionHandler: nil)
        }
    }
    
    private func removeDeliveredNotificationIfThereIsAny() {
        let center = UNUserNotificationCenter.current()
        center.removeAllDeliveredNotifications()
    }
}

// MARK: - UNUserNotificationCenterDelegate
class UserNotificationCenterDelegate:NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert,.sound])
    }
}

// MARK: - Background task type
enum BackgroundTaskType:Int {
    case requestRemoteNotificationRegister
    case checkNofifyUser
}
