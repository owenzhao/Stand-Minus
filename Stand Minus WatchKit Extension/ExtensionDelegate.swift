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
    var nows:[Date] = []
    var fireDates:[Date] = []

    func applicationDidFinishLaunching() {
        // Perform any final initialization of your application.
        NSLog("app did finish launching")
    }

    func applicationDidBecomeActive() {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        NSLog("app did become active")
//        standardPrecedure()
    }

    func applicationWillResignActive() {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, etc.
        NSLog("app will resign active")
    }
    
    deinit {
        ComplicationQuery.terminate()
        ComplicationData.terminate()
    }
    
    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        // Sent when the system needs to launch the application in the background to process tasks. Tasks arrive in a set, so loop through and process each one.
        for task in backgroundTasks {
            // Use a switch statement to check the task type
            switch task {
            case let backgroundTask as WKApplicationRefreshBackgroundTask:
                // Be sure to complete the background task once you’re done.
                standardPrecedure()
                backgroundTask.setTaskCompleted()
            case let snapshotTask as WKSnapshotRefreshBackgroundTask:
                // Snapshot tasks have a unique completion call, make sure to set your expiration date
                snapshotTask.setTaskCompleted(restoredDefaultState: true, estimatedSnapshotExpiration: Date.distantFuture, userInfo: nil)
            case let connectivityTask as WKWatchConnectivityRefreshBackgroundTask:
                // Be sure to complete the connectivity task once you’re done.
                connectivityTask.setTaskCompleted()
            case let urlSessionTask as WKURLSessionRefreshBackgroundTask:
                // Be sure to complete the URL session task once you’re done.
                urlSessionTask.setTaskCompleted()
            default:
                // make sure to complete unhandled task types
                task.setTaskCompleted()
            }
        }
    }
    
    func standardPrecedure() {
        let server = CLKComplicationServer.sharedInstance()
        let now = Date()
        self.nows.append(now)
        
        let query = ComplicationQuery.shared()
        
        func queryStandup() {
            query.start(at: now) {
                let hasComplication = _hasComplication()
                if hasComplication {
                    updateComplications()
                }
                self.arrangeNextBackgroundTask(at: now)
//                self.updateUI()
            }
        }
        
        func _hasComplication() -> Bool {
            if let complications = server.activeComplications, !complications.isEmpty {
                return true
            }
            
            return false
        }
        
        func updateComplications() {
            if shouldUpdateComplications() {
                updateComplicationsNow()
            }
        }
        
        func shouldUpdateComplications() -> Bool {
            return query.shouldUpdateComplication
        }
        
        func updateComplicationsNow() {
            server.activeComplications!.forEach { server.reloadTimeline(for: $0) }
        }
        
        queryStandup()
    }
    
    func arrangeNextBackgroundTask(at now:Date) {
        func calculateNextFireDate() -> Date {
            let data = ComplicationData.shared()
            let cal = Calendar(identifier: .gregorian)
            
            func shouldNotifyUser() -> Bool {
                return data.shouldNotifyUser
            }
            func hasStood() -> Bool {
                return data.hasStood
            }
            func nextWholeHour() -> Date {
                var cps = cal.dateComponents([.year, .month, .day, .hour], from: now)
                cps.hour! += 1
                ExtensionCurrentHourState.shared = .alreadyStood
                
                return cal.date(from: cps)!
            }
            func currentMinute() -> Int {
                return cal.component(.minute, from: now)
            }
            func notifyUser() {
                let center = UNUserNotificationCenter.current()
                if center.delegate == nil { center.delegate = self }
                center.getNotificationSettings { (notificationSettings) in
                    let id = UUID().uuidString
                    let content = { () -> UNMutableNotificationContent in
                        let mc = UNMutableNotificationContent()
                        mc.title = NSLocalizedString("Stand Up Notification", comment: "Stand Up Notification Title")
                        mc.body = NSLocalizedString("Please stand up and do some activice for one minute", comment: "Stand Up Notification Body")
                        
                        if notificationSettings.soundSetting == .enabled {
                            mc.sound = UNNotificationSound.default()
                        }
                        
                        return mc
                    }()
                    let request = UNNotificationRequest(identifier: id, content: content, trigger: nil) // nil means call the trigger immediately
                    center.add(request, withCompletionHandler: nil)
                }
            }
            
            if shouldNotifyUser() && !hasStood() {
                let minute = currentMinute()
                switch minute {
                case 0..<50:
                    var cps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: now)
                    cps.minute = 50
                    let date = cal.date(from: cps)!
                    ExtensionCurrentHourState.shared = .notNotifyUser
                    
                    return date
                default: //(50..<60)
                    if ExtensionCurrentHourState.shared == .notNotifyUser {
                        notifyUser()
                        ExtensionCurrentHourState.shared = .alreadyNotifyUser
                    }
                    return nextWholeHour()
                }
            }
            else {
                return nextWholeHour()
            }
            
        }
        
        // for temp test
        
        let fireDate = calculateNextFireDate()
        self.fireDates.append(fireDate)
        WKExtension.shared().scheduleBackgroundRefresh(withPreferredDate: fireDate, userInfo: nil) { (error) in
            if error == nil {
                let ds = DateFormatter.localizedString(from: fireDate, dateStyle: .none, timeStyle: .medium)
                NSLog("arrange background task at %@", ds)
            }
        }
    }
    
    func updateUI() {
        
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension ExtensionDelegate:UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert,.sound])
    }
}


enum ExtensionCurrentHourState {
    case notNotifyUser
    case alreadyNotifyUser
    case alreadyStood
    
    static var shared:ExtensionCurrentHourState = .notNotifyUser
}
