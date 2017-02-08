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

struct ArrangeDate {
    var date:Date! = nil
    let by:String
    
    init(by:String) {
        self.by = by
    }
}

class ExtensionDelegate: NSObject, WKExtensionDelegate {
    private let cal = Calendar(identifier: .gregorian)
    unowned private let data = ComplicationData.shared()
    
    var state:ExtensionCurrentHourState = .notSet
    
    func isTheSameState(s1:ExtensionCurrentHourState, s2:ExtensionCurrentHourState) -> Bool {
        guard s1 == s2 else { return false }
        
        return false
    }
    
    var arrangeDate:ArrangeDate! = nil
    var arrangeDates:[ArrangeDate] = [] // by, date
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
                let now = Date()
                fireDates.append(now)

                self.arrangeDate = ArrangeDate(by: "after query")
                queryStandup(at: now, shouldArrangeBackgroundTask: true)
                
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
    
    func arrangeNextBackgroundTask(at now:Date) {
        func calculateNextFireDate() -> Date {
            func shouldNotifyUser() -> Bool {
                return data.shouldNotifyUser
            }
            func hasStood() -> Bool {
                return data.hasStood
            }
            func total() -> Int {
                return data.stoodCount
            }
            func nextWholeHour(cps:inout DateComponents) {
                cps.hour! += 1
                cps.minute = 0
            }
            func fiftyMinutesInThisHour(cps:inout DateComponents) {
                cps.minute = 50
                state = .notNotifyUser(at: now)
            }
            func fiftyMinutesInNextHour(cps:inout DateComponents) {
                cps.hour! += 1
                cps.minute = 50
                state = .notNotifyUser(at: now)
            }
            func twelveFiftyInNextDay(cps:inout DateComponents) {
                cps.day! += 1
                cps.hour = 12
                cps.minute = 50
                state = .notNotifyUser(at: now)
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
                        mc.title = NSLocalizedString("Stand Up!", comment: "Stand Up Notification Title")
                        mc.body = NSLocalizedString("Class begins!(Err, no...) Please do some activity for at least one minute.", comment: "Stand Up Notification Body")
                        
                        if notificationSettings.soundSetting == .enabled {
                            mc.sound = UNNotificationSound.default()
                        }
                        
                        return mc
                    }()
                    let request = UNNotificationRequest(identifier: id, content: content, trigger: nil) // nil means call the trigger immediately
                    center.add(request, withCompletionHandler: nil)
                }
            }
            
            let hasComplication = _hasComplication()
            var cps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: now)
            if hasComplication {
                if shouldNotifyUser() {
                    if hasStood() {
                        nextWholeHour(cps: &cps)
                    }
                    else {
                        switch cps.minute! {
                        case 0..<50:
                            fiftyMinutesInThisHour(cps: &cps)
                        default: //(50..<60)
                            if state == .notNotifyUser(at: now) {
                                notifyUser()
                                state = .alreadyNotifyUser(at: now)
                            }
                            nextWholeHour(cps: &cps)
                        }
                    }
                }
                else {
                    nextWholeHour(cps: &cps)
                }
            }
            else {
                if shouldNotifyUser() {
                    if hasStood() {
                        if cps.hour! != 23 {
                            fiftyMinutesInNextHour(cps:&cps)
                        }
                        else {
                            twelveFiftyInNextDay(cps: &cps)
                        }
                    }
                    else {
                        switch cps.minute! {
                        case 0..<50:
                            cps.minute = 50
                            state = .notNotifyUser(at: now)
                        default: // 50..<60
                            if state != .alreadyNotifyUser(at: now) {
                                notifyUser()
                                state = .alreadyNotifyUser(at: now)
                            }
                            fiftyMinutesInNextHour(cps: &cps)
                        }
                    }
                }
                else {
                    cps.hour! += 12 - total() + (hasStood() ? 1 : 0)
                    if cps.hour! > 23 {
                        twelveFiftyInNextDay(cps: &cps)
                    }
                    else {
                        cps.minute = 50
                    }
                    state = .notNotifyUser(at: now)
                }
            }
            
            return cal.date(from: cps)!
        }
        
        let fireDate = calculateNextFireDate()
        arrangeDate.date = fireDate
        arrangeDates.append(arrangeDate)
        WKExtension.shared().scheduleBackgroundRefresh(withPreferredDate: fireDate, userInfo: nil) { (error) in
            if error == nil {
                let ds = DateFormatter.localizedString(from: fireDate, dateStyle: .none, timeStyle: .medium)
                NSLog("arrange background task at %@", ds)
            }
        }
    }
    
    func _hasComplication() -> Bool {
        let server = CLKComplicationServer.sharedInstance()
        if let complications = server.activeComplications, !complications.isEmpty {
            return true
        }
        
        return false
    }
    
    func queryStandup(at now:Date, shouldArrangeBackgroundTask:Bool) {
        let server = CLKComplicationServer.sharedInstance()
        
        let query = ComplicationQuery.shared()
        
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
        
        query.start(at: now) {
            let hasComplication = self._hasComplication()
            if hasComplication {
                updateComplications()
            }
            if shouldArrangeBackgroundTask { self.arrangeNextBackgroundTask(at: now) }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension ExtensionDelegate:UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert,.sound])
    }
}


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
