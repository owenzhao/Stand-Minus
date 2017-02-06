//
//  ComplicationData.swift
//  Stand Minus
//
//  Created by 肇鑫 on 2017-2-6.
//  Copyright © 2017年 ParusSoft.com. All rights reserved.
//

import Foundation
import HealthKit
import ClockKit

class ComplicationData {
    private static var instance:ComplicationData? = nil
    
    private init() { }
    
    class func shared() -> ComplicationData {
        if instance == nil {
            instance = ComplicationData()
        }
        
        return instance!
    }
    
    class func terminate() {
        instance = nil
    }
    
    private var _samples:[HKCategorySample] = []
    private var _stoodCount = 0
    private var _hasStood = false
    private let cal = Calendar(identifier: .gregorian)
    
    var sample:[HKCategorySample]? {
        return _samples
    }
    var stoodCount:Int {
        return _stoodCount
    }
    var hasStood:Bool {
        return _hasStood
    }
    var shouldNotifyUser:Bool {
        return _stoodCount >= 12
    }
    
    func delete(_ deletedObjects:[HKDeletedObject]) {
        for d in deletedObjects {
            for s in _samples {
                if d.uuid == s.uuid, let index = _samples.index(of: s) {
                    _samples.remove(at: index)
                }
            }
        }
    }
    
    func append(_ samples:[HKCategorySample]) {
        _samples.append(contentsOf: samples)
    }
    
    func assign(_ samples:[HKCategorySample]) {
        _samples = samples
    }
    
    func update(at now:Date) {
        func hourOf(_ date:Date) -> Int {
            return cal.component(.hour, from: date)
        }
        
        func stoodCount() {
            _stoodCount = _samples.reduce(0, { (result, nextSample) -> Int in
                let value = (nextSample.value == HKCategoryValueAppleStandHour.stood.rawValue ? 1 : 0)
                return result + value
            })
        }
        
        func hasStood() {
            if let latestSample = (_samples.max { $0.0.startDate < $0.1.startDate }) {
                let hourInLast = hourOf(latestSample.startDate)
                let hourNow = hourOf(now)
                
                _hasStood = hourInLast == hourNow
            }
            else {
                _hasStood = false
            }
        }
        
        stoodCount()
        hasStood()
        
        updateEntry(at: now)
    }
    
    // MARK: - entry
    private var _entry: CLKComplicationTimelineEntry? = nil
    var entry: CLKComplicationTimelineEntry? {
        return _entry
    }
    
    func updateEntry(at now:Date) {
        let provider = CLKSimpleTextProvider(text: String(_stoodCount))
        let template = CLKComplicationTemplateModularSmallRingText()
        template.ringStyle = .closed
        template.fillFraction = _hasStood ? 1.0 : 0.5
        template.textProvider = provider
        
        _entry = CLKComplicationTimelineEntry(date: now, complicationTemplate: template)
    }
}
