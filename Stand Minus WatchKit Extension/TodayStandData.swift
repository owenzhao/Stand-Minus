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

class TodayStandData {
    private static var instance:TodayStandData? = nil
    
    private init() { }
    
    class func shared() -> TodayStandData {
        if instance == nil {
            instance = TodayStandData()
        }
        
        return instance!
    }
    
    class func terminate() {
        instance = nil
    }
    
    private(set) var samples:[HKCategorySample] = []
    private(set) var total = 0
    private(set) var hasStoodInCurrentHour = false {
        didSet {
            let defaults = UserDefaults.standard
            defaults.set(hasStoodInCurrentHour, forKey: DefaultsKey.hasStoodKey)
        }
    }
    private let calendar = Calendar(identifier: .gregorian)
    
    var shouldNotifyUser:Bool {
        return total >= 12
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
            return calendar.component(.hour, from: date)
        }
        
        func countTotal() {
            self.total = samples.reduce(0) { (result, nextSample) -> Int in
                // FIXME: next line depends on the HKCategoryValueAppleStandHour.rawValue to be stand(0) and idle(1)
                // should use `let value = (nextSample.value == HKCategoryValueAppleStandHour.stood.rawValue ? 1 : 0)`
                // but above line is less effecient as it use a question tuple.
                let value = 1 - nextSample.value
                return result + value
            }
        }
        
        func judgeHasStoodInCurrentHour() {
            if let latestSample = (samples.max { $0.startDate < $1.startDate }) {
                let hourInLatest = hourOf(latestSample.startDate)
                let hourNow = hourOf(now)
                
                self.hasStoodInCurrentHour = hourInLatest == hourNow
            }
            else {
                self.hasStoodInCurrentHour = false
            }
        }
        
        countTotal()
        judgeHasStoodInCurrentHour()
    }
}

// MARK: - for interface controller
extension TodayStandData {
    func explicitlySetTotal(_ total:Int) {
        self.total = total
    }
    
    func explicitlySetHasStoodInCurrentHour(_ hasStoodInCurrentHour:Bool) {
        self.hasStoodInCurrentHour = hasStoodInCurrentHour
    }
}
