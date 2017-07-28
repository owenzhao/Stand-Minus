//
//  ComplicationController.swift
//  Stand Minus WatchKit Extension
//
//  Created by 肇鑫 on 2017-1-31.
//  Copyright © 2017年 ParusSoft.com. All rights reserved.
//

import ClockKit
import WatchKit
import HealthKit

class ComplicationController: NSObject, CLKComplicationDataSource {
    deinit {
        StandHourQuery.terminate()
        TodayStandData.terminate()
    }

    unowned private let todayStandData = TodayStandData.shared()
    unowned private let query = StandHourQuery.shared()
    
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
        let now = Date()
        
        func entryOf(_ complication:CLKComplication) -> CLKComplicationTimelineEntry {
            let template:CLKComplicationTemplate
            let textProvider = CLKSimpleTextProvider(text: String(self.todayStandData.total))
            switch complication.family {
            case .circularSmall:
                template = CLKComplicationTemplateCircularSmallRingText()
            case .modularSmall:
                template = CLKComplicationTemplateModularSmallRingText()
            case .utilitarianSmallFlat:
                template = CLKComplicationTemplateUtilitarianSmallFlat()
            default: // utilitarianSmall
                template = CLKComplicationTemplateUtilitarianSmallFlat()
            }
            
            if complication.family == .utilitarianSmall || complication.family == .utilitarianSmallFlat {
                let smallFlattemplate = template as! CLKComplicationTemplateUtilitarianSmallFlat
                let imageProvider = CLKImageProvider(onePieceImage: self.todayStandData.hasStoodInCurrentHour ? #imageLiteral(resourceName: "has stood") : #imageLiteral(resourceName: "not stood"))
                smallFlattemplate.imageProvider = imageProvider
                smallFlattemplate.textProvider = textProvider
            }
            else {
                let smallRingTextTemplate = template as! SmallRingTextTemplateProtocol
                smallRingTextTemplate.ringStyle = .closed
                smallRingTextTemplate.fillFraction = self.todayStandData.hasStoodInCurrentHour ? 1.0 : 0.5
                smallRingTextTemplate.textProvider = textProvider
            }
            
            return CLKComplicationTimelineEntry(date: now, complicationTemplate: template)
        }
        
        if query.complicationShouldReQuery {
            let preResultsHander:HKSampleQuery.PreResultsHandler = { [unowned self] (now, _) -> HKSampleQuery.ResultsHandler in
                return { [unowned self] (_, samples, error) in
                    guard error == nil else {
                        fatalError(error!.localizedDescription)
                    }
                    
                    if let samples = samples as? [HKCategorySample], let lastSample = samples.last {
                        let total = samples.reduce(0) { (result, sample) -> Int in
                            result + (1 - sample.value)
                        }
                        
                        var hassStoodInCurrentHour = false
                        
                        if lastSample.value == HKCategoryValueAppleStandHour.stood.rawValue {
                            let calendar = Calendar(identifier: .gregorian)
                            let currentHour = calendar.component(.hour, from: now)
                            let lastSampleHour = calendar.component(.hour, from: lastSample.startDate)
                            hassStoodInCurrentHour = (currentHour == lastSampleHour)
                        }
                        
                        self.todayStandData.explicitlySetTotal(total)
                        self.todayStandData.explicitlySetHasStoodInCurrentHour(hassStoodInCurrentHour)
                    } else {
                        self.todayStandData.explicitlySetTotal(0)
                        self.todayStandData.explicitlySetHasStoodInCurrentHour(false)
                    }
                    
                    self.query.complicationShouldReQuery = false
                    handler(entryOf(complication))
                    
                    self.query.arrangeNextBackgroundTask(at: now, hasComplication: true)
                }
            }
            
            self.query.executeSampleQueryWithComplication(preResultsHandler: preResultsHander)
        }
        else {
            handler(entryOf(complication))
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
        func templateOf() -> CLKComplicationTemplate {
            let template:CLKComplicationTemplate
            let textProvider = CLKSimpleTextProvider(text: String(self.todayStandData.total))
            switch complication.family {
            case .circularSmall:
                template = CLKComplicationTemplateCircularSmallRingText()
            case .modularSmall:
                template = CLKComplicationTemplateModularSmallRingText()
            case .utilitarianSmallFlat:
                template = CLKComplicationTemplateUtilitarianSmallFlat()
            default: // utilitarianSmall
                template = CLKComplicationTemplateUtilitarianSmallFlat() // CLKComplicationTemplateUtilitarianSmallRingText()
            }
            
            if complication.family == .utilitarianSmall || complication.family == .utilitarianSmallFlat {
                let smallFlattemplate = template as! CLKComplicationTemplateUtilitarianSmallFlat
                let imageProvider = CLKImageProvider(onePieceImage: #imageLiteral(resourceName: "has stood"))
                smallFlattemplate.imageProvider = imageProvider
                smallFlattemplate.textProvider = textProvider
            }
            else {
                let smallRingTextTemplate = template as! SmallRingTextTemplateProtocol
                smallRingTextTemplate.ringStyle = .closed
                smallRingTextTemplate.fillFraction = 1.0
                smallRingTextTemplate.textProvider = textProvider
            }
            
            return template
        }
        
        handler(templateOf())
    }
}

protocol SmallRingTextTemplateProtocol:class {
    var textProvider: CLKTextProvider { get set }
    var ringStyle: CLKComplicationRingStyle { get set }
    var fillFraction: Float { get set }
}

//extension CLKComplicationTemplateExtraLargeRingText: SmallRingText {} // won't use now, as it can't show realtime results
extension CLKComplicationTemplateModularSmallRingText: SmallRingTextTemplateProtocol {}
extension CLKComplicationTemplateCircularSmallRingText: SmallRingTextTemplateProtocol {}
extension CLKComplicationTemplateUtilitarianSmallRingText: SmallRingTextTemplateProtocol {}
