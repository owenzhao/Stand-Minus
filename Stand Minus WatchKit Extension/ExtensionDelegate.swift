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

class ExtensionDelegate: NSObject, WKExtensionDelegate {
    private let cal = Calendar(identifier: .gregorian)
    unowned private let data = TodayStandData.shared()
    lazy private var updateComplicationDelegate:UpdateComplicationDelegate = UpdateComplicationDelegate()
    
    
    private var anchor:HKQueryAnchor? = nil
    private var isFirstQuery = true
    
    func applicationDidFinishLaunching() {
        // Perform any final initialization of your application.
        UNUserNotificationCenter.current().requestAuthorization(options: [.sound, .alert]) { (success, error) in
            if error == nil && success {
                
            }
        }
    }
    
    deinit {
        StandHourQuery.terminate()
        TodayStandData.terminate()
    }
    
    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        // Sent when the system needs to launch the application in the background to process tasks. Tasks arrive in a set, so loop through and process each one.
        for task in backgroundTasks {
            // Use a switch statement to check the task type
            switch task {
            case let backgroundTask as WKApplicationRefreshBackgroundTask:
                // Be sure to complete the background task once you’re done.
                let query = StandHourQuery.shared()
                if query.complicationShouldReQuery { query.complicationShouldReQuery = false }
                
                let preResultsHandler:HKAnchoredObjectQuery.PreResultsHandler = { [unowned self] (now, hasComplication) -> HKAnchoredObjectQuery.ResultsHandler in
                    
                    return { [unowned self] (_, samples, deletedObjects, nextAnchor, error) in
                        defer {
                            backgroundTask.setTaskCompletedWithSnapshot(false)
                        }
                        
                        if error == nil {
                            defer {
                                self.anchor = nextAnchor
                            }
                            
                            if self.isFirstQuery {
                                defer { self.isFirstQuery = false }
                                self.data.assign(samples as! [HKCategorySample])
                            }
                            else {
                                if let deletedObjects = deletedObjects {
                                    self.data.delete(deletedObjects)
                                }
                                if let samples = samples as? [HKCategorySample] {
                                    self.data.append(samples)
                                }
                            }
                            
                            self.data.update(at: now) // // calculate data
                            
                            if hasComplication {
                                self.updateComplications()
                            }
                            
                            query.arrangeNextBackgroundTask(at: now, hasComplication: hasComplication)
                        }
                        else { // device is locked. **query failed, reason: Protected health data is inaccessible**
                            query.complicationShouldReQuery = true
                            query.arrangeNextBackgroundTaskWhenDeviceIsLocked(at: now, hasComplication: hasComplication)
                        }
                    }
                }
                
                query.executeAnchorObjectQuery(preResultsHanlder: preResultsHandler)
                
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

// MARK: - UpdateComplicationDelegate

protocol UpdateComplicationDelegateProtocol {
    var hasComplication:Bool { get }
    func shouldUpdateComplications() -> Bool
}

class UpdateComplicationDelegate:UpdateComplicationDelegateProtocol {
    private let server = CLKComplicationServer.sharedInstance()
    private let data = TodayStandData.shared()
    
    private var standCount:Int! = nil
    private var hasStood:Bool! = nil
    
    var hasComplication:Bool {
        if let complications = server.activeComplications, !complications.isEmpty { return true }
        return false
    }
    
    func shouldUpdateComplications() -> Bool {
        if standCount == nil || standCount != data.total || hasStood != data.hasStoodInCurrentHour {
            standCount = data.total
            hasStood = data.hasStoodInCurrentHour
            
            return true
        }
        
        return false
    }
}

// MARK: - ExtensionCurrentHourState

enum ExtensionCurrentHourState {
    case notSet
    case notNotifyUser(at:Date)
    case alreadyNotifyUser(at:Date)
    
    static func == (left:ExtensionCurrentHourState, right:ExtensionCurrentHourState) -> Bool {
        func inTheSampeHour(_ last:Date, _ now:Date) -> Bool {
            let cal = Calendar(identifier: .gregorian)
            let hourInLast = cal.component(.hour, from: last)
            let hourNow = cal.component(.hour, from: now)
            
            return hourInLast == hourNow && now.timeIntervalSince(last) < 60 * 60
        }
        
        switch left {
        case .notSet:
            switch right {
            case .notSet:
                return true
            default:
                return false
            }
        case .notNotifyUser(let last):
            switch right {
            case .notNotifyUser(let now):
                return inTheSampeHour(last, now)
            default:
                return false
            }
        case .alreadyNotifyUser(let last):
            switch right {
            case .alreadyNotifyUser(let now):
                return inTheSampeHour(last, now)
            default:
                return false
            }
        }
    }
    
    static func != (left:ExtensionCurrentHourState, right:ExtensionCurrentHourState) -> Bool {
        return !(left == right)
    }
}
