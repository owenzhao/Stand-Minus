//
//  StandHourQuery.swift
//  Stand Minus
//
//  Created by 肇鑫 on 2017-2-6.
//  Copyright © 2017年 ParusSoft.com. All rights reserved.
//

import Foundation
import HealthKit
import WatchKit
import UserNotifications

class StandHourQuery {
    private static var instance:StandHourQuery? = nil
    unowned private let data = TodayStandData.shared()
    private var state:ExtensionCurrentHourState = .notSet
    private lazy var userNotificationCenterDelegate = UserNotificationCenterDelegate()
    
    private init() { }
    
    class func shared() -> StandHourQuery {
        if instance == nil { instance = StandHourQuery() }
        return instance!
    }
    
    class func terminate() {
        instance = nil
    }
    
    private var anchor:HKQueryAnchor? = nil
    private var predicate:NSPredicate! = nil
    private let calendar = Calendar(identifier: .gregorian)
    private let sampleType = HKObjectType.categoryType(forIdentifier: .appleStandHour)!
    private let store = HKHealthStore()
    private var hasComplication:Bool {
        if let _ = CLKComplicationServer.sharedInstance().activeComplications {
            return true
        }
        
        return false
    }
    
    var complicationShouldReQuery = true
//    private var delegate:StandHourQueryDelegate!
    
    func executeAnchorObjectQuery(preResultsHanlder:@escaping HKAnchoredObjectQuery.PreResultsHandler) {
        let now = Date()
        createPredicate(at: now)
        
        let query = HKAnchoredObjectQuery(type: sampleType, predicate: predicate, anchor: anchor, limit: HKObjectQueryNoLimit, resultsHandler: preResultsHanlder(now, hasComplication))

        excuteHKQuery(query, at: now)
    }
    
    func excuteSampleQuery(preResultsHandler:@escaping HKSampleQuery.PreResultsHandler) {
        let now = Date()
        createPredicate(at: now)
        let soreDescrptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        let query = HKSampleQuery(sampleType: sampleType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [soreDescrptor], resultsHandler: preResultsHandler(now, hasComplication))
        
        excuteHKQuery(query, at: now)
    }
    
    private func excuteHKQuery(_ query:HKQuery, at now:Date) {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: DefaultsKey.hasStoodKey)
        defaults.set(now.timeIntervalSinceReferenceDate, forKey:DefaultsKey.lastQueryTimeIntervalSinceReferenceDateKey)
        
        store.execute(query)
    }
    
    private func createPredicate(at now:Date) {
        let cps = calendar.dateComponents([.year, .month, .day], from: now)
        let zeroHour = calendar.date(from: cps)
        let midnight = zeroHour?.addingTimeInterval(24 * 60 * 60)
        
        predicate = HKQuery.predicateForSamples(withStart: zeroHour, end: midnight, options: .strictStartDate)
    }
}

// MARK: - arrange next background task
extension StandHourQuery {
    func arrangeNextBackgroundTask(at now:Date, hasComplication: Bool) {
        func calculateNextQueryDate() -> Date {
            func shouldNotifyUser() -> Bool {
                return data.shouldNotifyUser
            }
            func hasStood() -> Bool {
                return data.hasStoodInCurrentHour
            }
            func total() -> Int {
                return data.total
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
                return calendar.component(.minute, from: now)
            }
            
            var cps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
            
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
            
            return calendar.date(from: cps)!
        }
        
        let nextQueryDate = calculateNextQueryDate()
        
        arrangeNextBackgroundTask(at: nextQueryDate)
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
    
    private func arrangeNextBackgroundTask(at fireDate:Date) {
        WKExtension.shared().scheduleBackgroundRefresh(withPreferredDate: fireDate, userInfo: nil) { (error) in
            if error == nil {
            }
        }
    }
    
    func arrangeNextBackgroundTaskWhenDeviceIsLocked(at now:Date, hasComplication:Bool) {
        var cps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        
        if hasComplication {
            switch cps.hour! {
            case 0..<6:
                nextWholeHour(cps: &cps)
            case 6..<12:
                switch cps.minute! {
                case 0..<20:
                    cps.minute = 20
                case 20..<40:
                    cps.minute = 40
                default: // 40 - 60
                    nextWholeHour(cps: &cps)
                }
            default: // 12...23
                switch cps.minute! {
                case 0..<20:
                    cps.minute = 20
                case 20..<40:
                    cps.minute = 40
                case 40..<50:
                    cps.minute = 50
                default: // 50 - 60
                    nextWholeHour(cps: &cps)
                }
            }
        }
        else {
            switch cps.hour! {
            case 0..<12:
                cps.hour = 12
                cps.minute = 50
            case 12..<23:
                switch cps.minute! {
                case 0..<50:
                    cps.minute = 50
                default: // 50 - 60
                    nextWholeHour(cps: &cps)
                }
            default: // 23
                switch cps.minute! {
                case 0..<50:
                    cps.minute = 50
                default: // 50 - 60
                    cps.day! += 1
                    cps.hour = 12
                    cps.minute = 50
                }
            }
        }
        
        let nextQueryDate = calendar.date(from: cps)!
        
        arrangeNextBackgroundTask(at: nextQueryDate)
    }
    
    private func nextWholeHour( cps:inout DateComponents) {
        cps.hour! += 1
        cps.minute = 0
    }
}

// MARK: - type alias
extension HKSampleQuery {
    typealias ResultsHandler = (HKSampleQuery, [HKSample]?, Error?) -> Void
    typealias PreResultsHandler = (Date, Bool) -> ResultsHandler
}

extension HKAnchoredObjectQuery {
    typealias ResultsHandler = (HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, Error?) -> Void
    typealias PreResultsHandler = (Date, Bool) -> ResultsHandler
}

// MARK: - UNUserNotificationCenterDelegate
class UserNotificationCenterDelegate:NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert,.sound])
    }
}
