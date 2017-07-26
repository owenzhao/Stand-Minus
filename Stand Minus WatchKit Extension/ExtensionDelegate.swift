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

class ExtensionDelegate: NSObject, WKExtensionDelegate {
    private let cal = Calendar(identifier: .gregorian)
    unowned private let data = CurrentHourData.shared()
    lazy private var updateComplicationDelegate:UpdateComplicationDelegate = UpdateComplicationDelegate()
    
    func isTheSameState(s1:ExtensionCurrentHourState, s2:ExtensionCurrentHourState) -> Bool {
        guard s1 == s2 else { return false }
        
        return false
    }

    func applicationDidFinishLaunching() {
        // Perform any final initialization of your application.
        UNUserNotificationCenter.current().requestAuthorization(options: [.sound, .alert]) { (success, error) in
            if error == nil && success {
                
            }
        }
    }
    
    deinit {
        StandHourQuery.terminate()
        CurrentHourData.terminate()
    }
    
    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        // Sent when the system needs to launch the application in the background to process tasks. Tasks arrive in a set, so loop through and process each one.
        for task in backgroundTasks {
            // Use a switch statement to check the task type
            switch task {
            case let backgroundTask as WKApplicationRefreshBackgroundTask:
                // Be sure to complete the background task once you’re done.
                let now = Date()
                let query = StandHourQuery.shared()
                if query.complicationShouldReQuery { query.complicationShouldReQuery = false }
                let defaults = UserDefaults.standard
                defaults.removeObject(forKey: DefaultsKey.hasStoodKey)
                defaults.set(now.timeIntervalSinceReferenceDate, forKey: DefaultsKey.lastQueryTimeIntervalSinceReferenceDateKey)

                let completionHandler:() -> () = {
                    backgroundTask.setTaskCompletedWithSnapshot(true)
                }
                
                startProcedure(at: now, completionHandler: completionHandler)
            case let snapshotTask as WKSnapshotRefreshBackgroundTask:
                // Snapshot tasks have a unique completion call, make sure to set your expiration date
                let completionHandler = {
                    snapshotTask.setTaskCompleted(restoredDefaultState: false, estimatedSnapshotExpiration: Date.distantFuture, userInfo: nil)
                }
                
                if let viewController = WKExtension.shared().rootInterfaceController as? InterfaceController {
                    viewController.updateUI(completionHandler:completionHandler)
                } else {
                    completionHandler()
                }
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
        if updateComplicationDelegate.hasComplication {
            if updateComplicationDelegate.shouldUpdateComplications() {
                server.activeComplications!.forEach { server.reloadTimeline(for: $0) }
            }
        }
        else {
            StandHourQuery.shared().complicationShouldReQuery = true
        }
    }
    
    func startProcedure(at now:Date, needToUpdateComplication:Bool = true, completionHandler: @escaping ()->()) {
        let query = StandHourQuery.shared()
        query.start(at: now, hasComplication:updateComplicationDelegate.hasComplication) { [unowned self] in // query
            if needToUpdateComplication { // update complications
                self.updateComplications()
            }
            
            completionHandler()
        }
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
    private let data = CurrentHourData.shared()
    
    private var standCount:Int! = nil
    private var hasStood:Bool! = nil
    
    var hasComplication:Bool {
        if let complications = server.activeComplications, !complications.isEmpty { return true }
        return false
    }
    
    func shouldUpdateComplications() -> Bool {
        if standCount == nil || standCount != data.standCount || hasStood != data.hasStood {
            standCount = data.standCount
            hasStood = data.hasStood
            
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
