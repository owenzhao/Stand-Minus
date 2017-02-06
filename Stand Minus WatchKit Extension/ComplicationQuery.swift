//
//  ComplicationQuery.swift
//  Stand Minus
//
//  Created by 肇鑫 on 2017-2-6.
//  Copyright © 2017年 ParusSoft.com. All rights reserved.
//

import Foundation
import HealthKit


class ComplicationQuery {
    private static var instance:ComplicationQuery? = nil
    
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
        func createPredicate() {
            let cps = cal.dateComponents([.year, .month, .day], from: now)
            let midnight = cal.date(from: cps)!
            
            predicate = HKQuery.predicateForSamples(withStart: midnight, end: midnight.addingTimeInterval(24 * 60 * 60), options: .strictStartDate)
        }
        
        func creatAnchorQuery() {
            anchorQuery = HKAnchoredObjectQuery(type: sampleType, predicate: predicate, anchor: anchor, limit: HKObjectQueryNoLimit) { [unowned self] (query, samples, deletedObjects, nextAnchor, error) -> Void in
                if error == nil {
                    let data = ComplicationData.shared()
                    
                    defer {
                        self.anchor = nextAnchor
                        if self._shouldUpdateComplication {
                            let data = ComplicationData.shared()
                            data.update(at: now)
                        }
                        completeHandler()
                        self._shouldUpdateComplication = false
                    }
                    
                    if self.isFirstQuery {
                        defer {
                            self._shouldUpdateComplication = true
                            self.isFirstQuery = false
                        }
                        
                        data.assign(samples as! [HKCategorySample])
                    }
                    else {
                        if let deletedObjects = deletedObjects, !deletedObjects.isEmpty {
                            data.delete(deletedObjects)
                            self._shouldUpdateComplication = true
                        }
                        if let samples = samples as? [HKCategorySample] {
                            data.append(samples)
                            self._shouldUpdateComplication = true
                        }
                    }
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
