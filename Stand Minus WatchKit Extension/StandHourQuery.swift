//
//  StandHourQuery.swift
//  Stand Minus
//
//  Created by 肇鑫 on 2017-2-6.
//  Copyright © 2017年 ParusSoft.com. All rights reserved.
//

import Foundation
import HealthKit
import UserNotifications

class StandHourQuery {
    static let calendar = Calendar(identifier: .gregorian)
    private static let sampleType = HKObjectType.categoryType(forIdentifier: .appleStandHour)!
    private static let store = HKHealthStore()
    
    func executeSampleQuery(resultsHandler:@escaping HKSampleQuery.ResultsHandler) {
        let now = Date()
        let predicate = createPredicate(at: now)
        let soreDescrptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        let query = HKSampleQuery(sampleType: StandHourQuery.sampleType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [soreDescrptor], resultsHandler: resultsHandler)
        
        executeHKQuery(query, at: now)
    }
    
    private func executeHKQuery(_ query:HKQuery, at now:Date) {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: DefaultsKey.hasStoodInCurrentHour.key)
        defaults.set(now.timeIntervalSinceReferenceDate, forKey:DefaultsKey.lastQueryTimeInterval.key)

        StandHourQuery.store.requestAuthorization(toShare: nil, read: [StandHourQuery.sampleType]) { (success, error) in
            if error == nil && success {
                StandHourQuery.store.execute(query)
            }
        }
    }
    
    private func createPredicate(at now:Date) -> NSPredicate {
        let cps = StandHourQuery.calendar.dateComponents([.year, .month, .day], from: now)
        let zeroHour = StandHourQuery.calendar.date(from: cps)
        
        let predicate = HKQuery.predicateForSamples(withStart: zeroHour, end: nil, options: .strictStartDate)
        
        return predicate
    }
}

// MARK: - type alias
extension HKSampleQuery {
    typealias ResultsHandler = (HKSampleQuery, [HKSample]?, Error?) -> Void
}
