//
//  StandHourQuery.swift
//  Stand Minus
//
//  Created by 肇鑫 on 2017-2-6.
//  Copyright © 2017年 ParusSoft.com. All rights reserved.
//

import Foundation
import HealthKit
//import WatchKit
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
    var hasComplication:Bool!
    
    func executeSampleQuery(preResultsHandler:@escaping HKSampleQuery.PreResultsHandler) {
        let now = Date()
        createPredicate(at: now)
        let soreDescrptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        let query = HKSampleQuery(sampleType: sampleType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [soreDescrptor], resultsHandler: preResultsHandler(now, true))
        
        executeHKQuery(query, at: now)
    }
    
    private func executeHKQuery(_ query:HKQuery, at now:Date) {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: DefaultsKey.hasStoodKey)
        defaults.set(now.timeIntervalSinceReferenceDate, forKey:DefaultsKey.lastQueryTimeIntervalSinceReferenceDateKey)
        data.now = now
        
        store.requestAuthorization(toShare: nil, read: [sampleType]) { [unowned self] (success, error) in
            if error == nil && success {
                self.store.execute(query)
            }
        }
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

// MARK: - ExtensionCurrentHourState
enum ExtensionCurrentHourState {
    case notSet
    case notNotifyUser(at:Date)
    case alreadyNotifyUser(at:Date)
    
    static func == (left:ExtensionCurrentHourState, right:ExtensionCurrentHourState) -> Bool {
        func inTheSampeHour(_ last:Date, _ now:Date) -> Bool {
            let calendar = Calendar(identifier: .gregorian)
            let hourInLast = calendar.component(.hour, from: last)
            let hourNow = calendar.component(.hour, from: now)
            
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
