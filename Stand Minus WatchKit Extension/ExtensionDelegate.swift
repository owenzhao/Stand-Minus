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
    
    var state:ExtensionCurrentHourState = .notSet
    
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
                defaults.set(now.timeIntervalSinceReferenceDate, forKey: DefaultsKey.lastQueryTimeIntervalSinceReferenceDateKey)

                let completionHandler = backgroundTask.setTaskCompleted
                startProcedure(at: now, completionHandler: completionHandler)
            case let snapshotTask as WKSnapshotRefreshBackgroundTask:
                // Snapshot tasks have a unique completion call, make sure to set your expiration date
                snapshotTask.setTaskCompleted(restoredDefaultState: false, estimatedSnapshotExpiration: Date.distantFuture, userInfo: nil)
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
    
    private func arrangeNextBackgroundTask(at now:Date) {
        func calculateNextQueryDate() -> Date {
            func shouldNotifyUser() -> Bool {
                return data.shouldNotifyUser
            }
            func hasStood() -> Bool {
                return data.hasStood
            }
            func total() -> Int {
                return data.standCount
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
            
            var cps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: now)
            if updateComplicationDelegate.hasComplication {
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
        
        let nextQueryDate = calculateNextQueryDate()
        
        WKExtension.shared().scheduleBackgroundRefresh(withPreferredDate: nextQueryDate, userInfo: nil) { (error) in
            if error == nil {
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
            self.data.update(at: now) // // calculate data
            if needToUpdateComplication { // update complications
                self.updateComplications()
            }
            self.arrangeNextBackgroundTask(at: now)
            
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
