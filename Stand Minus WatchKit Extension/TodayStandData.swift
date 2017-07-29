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
    
    private let calendar = Calendar(identifier: .gregorian)
    private(set) var total = 0
    private(set) var hasStoodInCurrentHour = false {
        didSet {
            let defaults = UserDefaults.standard
            defaults.set(hasStoodInCurrentHour, forKey: DefaultsKey.hasStoodKey)
        }
    }
    
    lazy var now = Date()
    
    var shouldNotifyUser:Bool {
        return total >= 12
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
