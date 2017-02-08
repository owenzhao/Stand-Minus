//
//  ComplicationQuery.swift
//  Stand Minus
//
//  Created by 肇鑫 on 2017-2-6.
//  Copyright © 2017年 ParusSoft.com. All rights reserved.
//

import Foundation
import HealthKit
import WatchKit


class ComplicationQuery {
    private static var instance:ComplicationQuery? = nil
    unowned private let data = ComplicationData.shared()
    
    private init() { }
    
    class func shared() -> ComplicationQuery {
        if instance == nil { instance = ComplicationQuery() }
        return instance!
    }
    
    class func terminate() {
        instance = nil
    }
    
    private var isFirstQuery = true
    private var anchor:HKQueryAnchor? = nil
    
    private var lastQueryDate:Date! = nil
    private var predicate:NSPredicate! = nil
    private var anchorQuery:HKAnchoredObjectQuery! = nil
    
    private let cal = Calendar(identifier: .gregorian)
    private let sampleType = HKObjectType.categoryType(forIdentifier: .appleStandHour)!
    private let store = HKHealthStore()
    
    private var _shouldUpdateComplication = false
    
    var shouldUpdateComplication:Bool {
        return _shouldUpdateComplication
    }
    
    private func dayOf(_ date:Date) -> Int {
        return cal.component(.day, from: date)
    }
    
    func start(at now:Date, completeHandler: @escaping () -> ()) {
        func arrangeNextBackgroundTaskWhenDeviceIsLocked() {
            func nextWholeHour( cps:inout DateComponents) {
                cps.hour! += 1
                cps.minute = 0
            }
            let delegate = WKExtension.shared().delegate as! ExtensionDelegate
            
            let hasComplication = delegate._hasComplication()
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
            
            let fireDate = cal.date(from: cps)!
            var arrangeDate = ArrangeDate(by:"device is locked")
            arrangeDate.date = fireDate
            delegate.arrangeDates.append(arrangeDate)
            WKExtension.shared().scheduleBackgroundRefresh(withPreferredDate: fireDate, userInfo: nil) { (error) in
                if error == nil {
                    let ds = DateFormatter.localizedString(from: fireDate, dateStyle: .none, timeStyle: .medium)
                    NSLog("arrange background task at %@", ds)
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
                        if self._shouldUpdateComplication {
                            self.data.update(at: now)
                        }
                        completeHandler()
                        self._shouldUpdateComplication = false
                    }
                    
                    if self.isFirstQuery {
                        defer {
                            self._shouldUpdateComplication = true
                            self.isFirstQuery = false
                        }
                        
                        self.data.assign(samples as! [HKCategorySample])
                    }
                    else {
                        if let deletedObjects = deletedObjects, !deletedObjects.isEmpty {
                            self.data.delete(deletedObjects)
                            self._shouldUpdateComplication = true
                        }
                        if let samples = samples as? [HKCategorySample] {
                            self.data.append(samples)
                            self._shouldUpdateComplication = true
                        }
                    }
                }
                else { // device is locked. **query failed, reason: Protected health data is inaccessible**
                    arrangeNextBackgroundTaskWhenDeviceIsLocked()
                }
            }
        }
        
        if isFirstQuery || (dayOf(lastQueryDate!) != dayOf(now))
        {
            defer { isFirstQuery = true }
            
            lastQueryDate = now
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
