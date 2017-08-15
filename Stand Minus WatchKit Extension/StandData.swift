//
//  CurrentHourData.swift
//  Stand Minus
//
//  Created by 肇鑫 on 2017-2-6.
//  Copyright © 2017年 ParusSoft.com. All rights reserved.
//

import Foundation
import HealthKit

struct StandData {
    private let defaults = UserDefaults.standard
    
    private(set) var total = 0 {
        didSet {
            defaults.set(total, forKey: DefaultsKey.total.key)
        }
    }
    
    private(set) var hasStoodInCurrentHour = false {
        didSet {
            defaults.set(hasStoodInCurrentHour, forKey: DefaultsKey.hasStoodInCurrentHour.key)
        }
    }
    
    var samples:[HKCategorySample] = [] {
        didSet {
            if let lastSample = samples.last {
                let total = samples.reduce(0) { (result, sample) -> Int in
                    result + (1 - sample.value)
                }
                
                var hasStoodInCurrentHour = false
                
                if lastSample.value == HKCategoryValueAppleStandHour.stood.rawValue {
                    let calendar = Calendar(identifier: .gregorian)
                    let timeInterval = defaults.double(forKey: DefaultsKey.lastQueryTimeInterval.key)
                    let now = Date(timeIntervalSinceReferenceDate: timeInterval)
                    let currentHour = calendar.component(.hour, from: now)
                    let lastSampleHour = calendar.component(.hour, from: lastSample.startDate)
                    hasStoodInCurrentHour = (currentHour == lastSampleHour)
                }
                
                self.total = total
                self.hasStoodInCurrentHour = hasStoodInCurrentHour
            }
            else {
                self.total = 0
                self.hasStoodInCurrentHour = false
            }
        }
    }
}
