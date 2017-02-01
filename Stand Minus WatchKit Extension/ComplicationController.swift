//
//  ComplicationController.swift
//  Stand Minus WatchKit Extension
//
//  Created by 肇鑫 on 2017-1-31.
//  Copyright © 2017年 ParusSoft.com. All rights reserved.
//

import ClockKit
import HealthKit
import WatchKit


class ComplicationController: NSObject, CLKComplicationDataSource {
    
    // MARK: - Timeline Configuration
    
    func getSupportedTimeTravelDirections(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimeTravelDirections) -> Void) {
        handler([])
    }
    
    func getTimelineStartDate(for complication: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
        handler(nil)
    }
    
    func getTimelineEndDate(for complication: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
        handler(nil)
    }
    
    func getPrivacyBehavior(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationPrivacyBehavior) -> Void) {
        handler(.hideOnLockScreen)
    }
    
    // MARK: - Timeline Population
    
    func getCurrentTimelineEntry(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void) {
        // Call the handler with the current timeline entry
        print("complcation updates")
        print()
        switch complication.family {
        case .modularSmall:
            let now = Date()
//            defer { TaskManager.excute(hasComplication: true, at: now) }
            defer { TaskManager.excute(for: .theWholeHour, at: now) }
            
            let data = ComplicationdData.shared()
            if data.currentTimeLineEntry == nil { data.update(at: now) { handler(data.currentTimeLineEntry!) } }
            else {
                handler(data.currentTimeLineEntry!)
            }
        default:
            handler(nil)
        }
    }
    
    func getTimelineEntries(for complication: CLKComplication, before date: Date, limit: Int, withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void) {
        // Call the handler with the timeline entries prior to the given date
        handler(nil)
    }
    
    func getTimelineEntries(for complication: CLKComplication, after date: Date, limit: Int, withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void) {
        // Call the handler with the timeline entries after to the given date
        handler(nil)
    }
    
    // MARK: - Placeholder Templates
    
    func getLocalizableSampleTemplate(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTemplate?) -> Void) {
        // This method will be called once per supported complication, and the results will be cached
        switch complication.family {
        case .modularSmall:
            let provider = CLKSimpleTextProvider(text: "10")
            let template = CLKComplicationTemplateModularSmallRingText()
            template.textProvider = provider
            
            handler(template)
        default:
            handler(nil)
        }
    }
    
}

class ComplicationdData {
    private static var instance:ComplicationdData? = nil
    private var _entry:CLKComplicationTimelineEntry? = nil
    private var _hasStood = false
    private var _total = 0
    private let store = HKHealthStore()
    private var anchor:HKQueryAnchor? = nil
    private var lastMidnight:Date? = nil
    private var latestSample:HKCategorySample? = nil
    
    private init() { }
    
    class func shared() -> ComplicationdData{
        if instance == nil { instance = ComplicationdData() }
        return instance!
    }
    
    
    var currentTimeLineEntry:CLKComplicationTimelineEntry? {
        return _entry
    }
    
    var hasStood:Bool { return _hasStood }
    var total:Int { return _total }
    
    func update(at now:Date, completeHandler: (() ->())? = nil) {
        let sampleType = HKObjectType.categoryType(forIdentifier: .appleStandHour)!
        let cal = Calendar(identifier: .gregorian)
        let cps = cal.dateComponents([.year, .month], from: now)
        let midNight = cal.date(from: cps)!
//        let predicate = HKQuery.predicateForSamples(withStart: midNight, end: now, options: .strictStartDate)
        let sortDesciptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
//        let query = HKSampleQuery(sampleType: sampleType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDesciptor]) { [unowned self] (query, samples, error) in
//            if error != nil {
//                if let todaySamples = samples as? [HKCategorySample] { // has record
//                    if let latestSample = todaySamples.last { // has latest sample
//                        let hourInLastest = cal.component(.hour, from: latestSample.startDate)
//                        let hourNow = cal.component(.hour, from: now)
//                        
//                        self._hasStood = hourInLastest == hourNow
//                    }
//                    else {
//                        self._hasStood = false
//                    }
//                    
//                    self._total = todaySamples.reduce(0, { (result, nextSample) -> Int in
//                        let value = nextSample.value == HKCategoryValueAppleStandHour.stood.rawValue ? 1 : 0
//                        return result + value
//                    })
//                    
//                    let provider = CLKSimpleTextProvider(text: String(self._total))
//                    let template = CLKComplicationTemplateModularSmallRingText()
//                    template.ringStyle = .closed
//                    template.fillFraction = self.hasStood ? 1 : 0.5
//                    template.textProvider = provider
//                    self._entry = CLKComplicationTimelineEntry(date: now, complicationTemplate: template)
//                }
//                else { // has no record
//                    self._hasStood = false
//                    self._total = 0
//                    let provider = CLKSimpleTextProvider(text: "0")
//                    let template = CLKComplicationTemplateModularSmallRingText()
//                    template.ringStyle = .closed
//                    template.fillFraction = 0.5
//                    template.textProvider = provider
//                    self._entry = CLKComplicationTimelineEntry(date: now, complicationTemplate: template)
//                }
//            }
//            
//            completeHandler?()
//            task?.setTaskCompleted()
//        }
//        
//        store.execute(query)
        
        if let lastMidnight = self.lastMidnight, lastMidnight != midNight {
            self.lastMidnight = midNight
            if anchor != nil { anchor = nil }
        }
        
        let anchorQuery = HKAnchoredObjectQuery(type: sampleType, predicate: nil, anchor: anchor, limit: HKObjectQueryNoLimit) { [unowned self] (query, samples, deletedObjects, nextAnchor, error) in
            func findTheLatest(_ samples:[HKCategorySample]) {
                if let latestSample = samples.max(by: { $0.0.startDate < $0.1.startDate }) {
                    if self.latestSample == nil || self.latestSample! != latestSample {
                        self.latestSample = latestSample
                    }
                }
            }
            
            func dealWith(_ samples:[HKCategorySample]) {
                findTheLatest(samples)
                if let latestSample = self.latestSample { // has latest sample
                    let hourInLastest = cal.component(.hour, from: latestSample.startDate)
                    let hourNow = cal.component(.hour, from: now)
                    
                    self._hasStood = hourInLastest == hourNow
                }
                else {
                    self._hasStood = false
                }
                
                self._total = samples.reduce(0, { (result, nextSample) -> Int in
                    let value = nextSample.value == HKCategoryValueAppleStandHour.stood.rawValue ? 1 : 0
                    return result + value
                })
                
                let provider = CLKSimpleTextProvider(text: String(self._total))
                let template = CLKComplicationTemplateModularSmallRingText()
                template.ringStyle = .closed
                template.fillFraction = self.hasStood ? 1 : 0.5
                template.textProvider = provider
                self._entry = CLKComplicationTimelineEntry(date: now, complicationTemplate: template)
            }
            
            func dealWithContinue(_ samples:[HKCategorySample]) {
                findTheLatest(samples)
                if let latestSample = self.latestSample { // has latest sample
                    let hourInLastest = cal.component(.hour, from: latestSample.startDate)
                    let hourNow = cal.component(.hour, from: now)
                    
                    self._hasStood = hourInLastest == hourNow
                }
                else {
                    self._hasStood = false
                }
                
                self._total = samples.reduce(self._total, { (result, nextSample) -> Int in
                    let value = nextSample.value == HKCategoryValueAppleStandHour.stood.rawValue ? 1 : 0
                    return result + value
                })
                
                let provider = CLKSimpleTextProvider(text: String(self._total))
                let template = CLKComplicationTemplateModularSmallRingText()
                template.ringStyle = .closed
                template.fillFraction = self.hasStood ? 1 : 0.5
                template.textProvider = provider
                self._entry = CLKComplicationTimelineEntry(date: now, complicationTemplate: template)
            }
            
            defer {
                self.anchor = nextAnchor
                
                completeHandler?()
            }
            
            if error == nil {
                // find brand new result or continue result
                if self.anchor == nil { // brand new result
                    if let todaySamples = samples as? [HKCategorySample] { dealWith(todaySamples.filter({ midNight < $0.endDate })) } // has records
                    else { // has no record
                        self._hasStood = false
                        self._total = 0
                        let provider = CLKSimpleTextProvider(text: "0")
                        let template = CLKComplicationTemplateModularSmallRingText()
                        template.ringStyle = .closed
                        template.fillFraction = 0.5
                        template.textProvider = provider
                        self._entry = CLKComplicationTimelineEntry(date: now, complicationTemplate: template)
                    }
                }
                else { // continue result
                    if let newSamples = samples as? [HKCategorySample] { dealWithContinue(newSamples) } // has new records
                    else { // has no new records
                        if let latestSample = self.latestSample { // has latest sample
                            let hourInLastest = cal.component(.hour, from: latestSample.startDate)
                            let hourNow = cal.component(.hour, from: now)
                            
                            self._hasStood = hourInLastest == hourNow
                        }
                        else {
                            self._hasStood = false
                        }
                    }
                    
                    let provider = CLKSimpleTextProvider(text: String(self._total))
                    let template = CLKComplicationTemplateModularSmallRingText()
                    template.ringStyle = .closed
                    template.fillFraction = self.hasStood ? 1 : 0.5
                    template.textProvider = provider
                    self._entry = CLKComplicationTimelineEntry(date: now, complicationTemplate: template)
                }
                
                // TODO: deal with newly deleted samples
            }
        }
        
        store.requestAuthorization(toShare: nil, read: [sampleType]) { (success, error) in
            guard error == nil else { fatalError(error!.localizedDescription) }
            if success {
                self.store.execute(anchorQuery)
            }
        }
    }
}
