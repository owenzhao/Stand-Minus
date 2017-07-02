//
//  CurrentHourData.swift
//  Stand Minus
//
//  Created by 肇鑫 on 2017-2-6.
//  Copyright © 2017年 ParusSoft.com. All rights reserved.
//

import Foundation
import HealthKit
import ClockKit
import WatchKit

class CurrentHourData {
    private static var instance:CurrentHourData? = nil
    
    private init() { }
    
    class func shared() -> CurrentHourData {
        if instance == nil {
            instance = CurrentHourData()
        }
        
        return instance!
    }
    
    class func terminate() {
        instance = nil
    }
    
    private(set) var samples:[HKCategorySample] = []
    private(set) var standCount = 0
    private(set) var hasStood = false {
        didSet {
            (WKExtension.shared().rootInterfaceController as! InterfaceController).hasStood = hasStood
        }
    }
    private let cal = Calendar(identifier: .gregorian)
    
    var shouldNotifyUser:Bool {
        return standCount >= 12
    }
    
    func delete(_ deletedObjects:[HKDeletedObject]) {
        for d in deletedObjects {
            for s in samples {
                if d.uuid == s.uuid, let index = samples.index(of: s) {
                    samples.remove(at: index)
                }
            }
        }
    }
    
    func append(_ samples:[HKCategorySample]) {
        self.samples.append(contentsOf: samples)
    }
    
    func assign(_ samples:[HKCategorySample]) {
        self.samples = samples
    }
    
    func update(at now:Date) {
        func hourOf(_ date:Date) -> Int {
            return cal.component(.hour, from: date)
        }
        
        func theStandCount() {
            self.standCount = samples.reduce(0, { (result, nextSample) -> Int in
                let value = (nextSample.value == HKCategoryValueAppleStandHour.stood.rawValue ? 1 : 0)
                return result + value
            })
        }
        
        func theHasStood() {
            if let latestSample = (samples.max { $0.startDate < $1.startDate }) {
                let hourInLast = hourOf(latestSample.startDate)
                let hourNow = hourOf(now)
                
                self.hasStood = hourInLast == hourNow
            }
            else {
                self.hasStood = false
            }
        }
        
        theStandCount()
        theHasStood()
    }
}
