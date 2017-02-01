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

    func applicationDidFinishLaunching() {
        // Perform any final initialization of your application.
    }

    func applicationDidBecomeActive() {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillResignActive() {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, etc.
    }

    var previousRequest:UNNotificationRequest? = nil
    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        let server = CLKComplicationServer.sharedInstance()
        func hasComplication() -> Bool {
            if let complications = server.activeComplications, complications.count > 0 {
                return true
            }
            
            return false
        }
        
        func updateComplication() {
            server.activeComplications?.forEach { server.extendTimeline(for: $0) }
        }
        
        func isNowTheNextWholeHour(_ now:Date) -> Bool {
            let cal = Calendar(identifier: .gregorian)
            let minute = cal.component(.minute, from: now)
            
            return !((50 ..< 60).contains(minute))
        }

        func hasStood() -> Bool {
            let data = ComplicationdData.shared()
            return data.hasStood
        }
        
        func removePreviousRequest() {
            let center = UNUserNotificationCenter.current()
            center.removeAllDeliveredNotifications()
            center.removeAllPendingNotificationRequests()
            
            previousRequest = nil
        }
        
        func notifyUserToStandUp() {
            let center = UNUserNotificationCenter.current()
            center.requestAuthorization(options: [.alert, .sound]) { (success, error) in
                guard error == nil else { fatalError(error!.localizedDescription) }
                if success {
                    removePreviousRequest()
                    let content:UNNotificationContent = {
                        let c = UNMutableNotificationContent()
                        c.title = NSLocalizedString("Stand up notification", comment: "Stand up notification title")
                        c.body = NSLocalizedString("Please stand up for one minutes", comment: "stand up notification body")
                        c.sound = UNNotificationSound.default()
                        
                        return c
                    }()
                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
                    self.previousRequest = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
                    center.add(self.previousRequest!, withCompletionHandler: { (error) in
                        guard error == nil else { fatalError(error!.localizedDescription) }
                    })
                }
            }
        }
        
        func notifyUserStandUpComplete() {
            let center = UNUserNotificationCenter.current()
            center.requestAuthorization(options: [.alert, .sound]) { (success, error) in
                guard error == nil else { fatalError(error!.localizedDescription) }
                if success {
                    removePreviousRequest()
                    let content:UNNotificationContent = {
                        let c = UNMutableNotificationContent()
                        c.title = NSLocalizedString("Stand up notification", comment: "Stand up notification title")
                        c.body = NSLocalizedString("Please stand up for one minutes", comment: "stand up notification body")
                        c.sound = UNNotificationSound.default()
                        
                        return c
                    }()
                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
                    self.previousRequest = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
                    center.add(self.previousRequest!, withCompletionHandler: { (error) in
                        guard error == nil else { fatalError(error!.localizedDescription) }
                    })
                }
            }
        }
        
        func excute(task:WKRefreshBackgroundTask) {
            let userInfo = task.userInfo as! [String:Int]
            let reason = TaskManager.Reason(rawValue: userInfo["rawValue"]!)!
            let now = Date()
            
            func theWholeHourRefresh() {
                defer {
                    let reason = TaskManager.Reason.theWholeHour
                    TaskManager.excute(for: reason, at: now)
                }
                if previousRequest != nil { removePreviousRequest() }
                if hasComplication() {
                    updateComplication()
                }
            }
            
            let data = ComplicationdData.shared()
            data.update(at: now) {
                defer { task.setTaskCompleted() }
                if reason == .theWholeHour { theWholeHourRefresh() }
                else {
                    if isNowTheNextWholeHour(now) { theWholeHourRefresh() }
                    else {
                        if hasStood() {
                            notifyUserStandUpComplete()
                            theWholeHourRefresh()
                        }
                        else {
                            switch reason {
                            case .notifyUser:
                                notifyUserToStandUp()
                                fallthrough
                            case .checkStoodFirst:
                                let reason = TaskManager.Reason.checkStoodFirst
                                TaskManager.excute(for: reason, at: now)
                            default:
                                break
                            }
                        }
                    }
                }
            }
        }
        // Sent when the system needs to launch the application in the background to process tasks. Tasks arrive in a set, so loop through and process each one.
        for task in backgroundTasks {
            // Use a switch statement to check the task type
            print("outside background task runs")
            switch task {
            case let backgroundTask as WKApplicationRefreshBackgroundTask:
                // Be sure to complete the background task once you’re done.
                print("background task runs")
                let reasonString = { () -> String in
                    let rawValue = (backgroundTask.userInfo as! [String:Int])["rawValue"]!
                    
                    switch TaskManager.Reason(rawValue: rawValue)! {
                    case .checkStoodFirst:
                        return "check stood first"
                    case .notifyUser:
                        return "notify user"
                    case .theWholeHour:
                        return "the whole hour"
                    }
                }()
                print("reason:\(reasonString)")
                excute(task: backgroundTask)
            case let snapshotTask as WKSnapshotRefreshBackgroundTask:
                // Snapshot tasks have a unique completion call, make sure to set your expiration date
                print("snap task runs")
                print()
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

}
