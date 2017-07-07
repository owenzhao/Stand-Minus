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

class StandHourQuery {
    private static var instance:StandHourQuery? = nil
    unowned private let data = CurrentHourData.shared()
    
    private init() { }
    
    class func shared() -> StandHourQuery {
        if instance == nil { instance = StandHourQuery() }
        return instance!
    }
    
    class func terminate() {
        instance = nil
    }
    
    private var isFirstQuery = true
    private var anchor:HKQueryAnchor? = nil
    
    private var predicate:NSPredicate! = nil
    private var anchorQuery:HKAnchoredObjectQuery! = nil
    
    private let cal = Calendar(identifier: .gregorian)
    private let sampleType = HKObjectType.categoryType(forIdentifier: .appleStandHour)!
    private let store = HKHealthStore()
    
    var complicationShouldReQuery = true
    private var delegate:StandHourQueryDelegate!
    
    func start(at now:Date, hasComplication:Bool, completeHandler: @escaping () -> ()) {
        func arrangeNextBackgroundTaskWhenDeviceIsLocked() {
            func nextWholeHour( cps:inout DateComponents) {
                cps.hour! += 1
                cps.minute = 0
            }

            var cps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: now)
            
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
            
            let nextQueryDate = cal.date(from: cps)!
            WKExtension.shared().scheduleBackgroundRefresh(withPreferredDate: nextQueryDate, userInfo: nil) { (error) in
                if error == nil {
                }
            }
        }
        
        func createPredicate() {
            let cps = cal.dateComponents([.year, .month, .day], from: now)
            let midnight = cal.date(from: cps)!
            
            predicate = HKQuery.predicateForSamples(withStart: midnight, end: midnight.addingTimeInterval(24 * 60 * 60), options: .strictStartDate)
        }
        
        func creatAnchorQuery() {
            anchorQuery = HKAnchoredObjectQuery(type: sampleType, predicate: predicate, anchor: anchor, limit: HKObjectQueryNoLimit) { [unowned self] (query, samples, deletedObjects, nextAnchor, error) -> Void in
                if error == nil {
                    defer {
                        self.anchor = nextAnchor
                        completeHandler()
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
                }
                else { // device is locked. **query failed, reason: Protected health data is inaccessible**
                    self.complicationShouldReQuery = true
                    let defaults = UserDefaults.standard
                    defaults.removeObject(forKey: DefaultsKey.hasStoodKey)
                    arrangeNextBackgroundTaskWhenDeviceIsLocked()
                }
            }
        }
        
        defer { delegate.lastQueryDate = now }
        
        if delegate == nil {
            delegate = StandHourQueryDelegate(now)
        }
        else {
            guard delegate.shouldQuery(at: now) else {
                completeHandler()
                return
            }
        }
        
        if delegate.shouldRecreatePredicate(isFirstQuery, now)
        {
            defer { isFirstQuery = true }
            
            anchor = nil
            
            createPredicate()
        }
        
        creatAnchorQuery()
        
        store.requestAuthorization(toShare: nil, read: [sampleType]) { [unowned self] (success, error) in
            if error == nil && success {
                self.store.execute(self.anchorQuery!)
            }
        }
    }
}

protocol StandHourQueryDelegateProtocol:class {
    var lastQueryDate: Date { get set }
    func shouldQuery(at now:Date) -> Bool
    func shouldRecreatePredicate(_ isFirstQuery:Bool, _ now:Date) -> Bool
}

class StandHourQueryDelegate:StandHourQueryDelegateProtocol {
    var lastQueryDate: Date
    unowned private let data = CurrentHourData.shared()

    private let cal = Calendar(identifier: .gregorian)
    
    init(_ lastQueryDate:Date) {
        self.lastQueryDate = lastQueryDate
    }
    
    func shouldQuery(at now:Date) -> Bool {
        func hourOf(_ date:Date) -> Int {
            return cal.component(.hour, from: date)
        }
        
        let value = !data.hasStood || !(now.timeIntervalSince(lastQueryDate) < 60 * 60 && hourOf(lastQueryDate) == hourOf(now))
        
        return value
    }
    
    func shouldRecreatePredicate(_ isFirstQuery:Bool, _ now:Date) -> Bool {
        func dayOf(_ date:Date) -> Int {
            return cal.component(.day, from: date)
        }
        
        return isFirstQuery || (dayOf(lastQueryDate) != dayOf(now))
    }
}
