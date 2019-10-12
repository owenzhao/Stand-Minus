//
//  ComplicationModel.swift
//  Stand Minus WatchKit Extension
//
//  Created by zhaoxin on 2019/10/11.
//  Copyright © 2019 ParusSoft.com. All rights reserved.
//

import Foundation
import HealthKit

struct ComplicationModel {
    static var today:Date? = nil
    
    let queryDate:Date
    let total:Int?
    let hasStoodInCurrentHour:Bool?
    
    var minute:Int {
        return StandHourQuery.calendar.component(.minute, from: queryDate)
    }
    
    init(queryDate:Date, samples:[HKCategorySample]) {
        self.queryDate = queryDate
        
        if let lastSample = samples.last {
            let total = samples.reduce(0) { (result, sample) -> Int in
                result + (1 - sample.value)
            }
            
            var hasStoodInCurrentHour = false
            
            if lastSample.value == HKCategoryValueAppleStandHour.stood.rawValue {
                let currentHour = StandHourQuery.calendar.component(.hour, from: queryDate)
                let lastSampleHour = StandHourQuery.calendar.component(.hour, from: lastSample.startDate)
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
    
    init(queryDate:Date) {
        self.queryDate = queryDate
        self.total = nil
        self.hasStoodInCurrentHour = nil
    }
}
