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
import WatchConnectivity

class ComplicationController: NSObject, CLKComplicationDataSource {
    private var queryOnce:Bool = true

    private lazy var query = StandHourQuery()
    private lazy var defaults = UserDefaults.standard
    
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
        if queryOnce {
            let preResultsHandler:HKSampleQuery.PreResultsHandler = { [unowned self] (now) -> HKSampleQuery.ResultsHandler in
                return { [unowned self] (_, samples, error) in
                    defer {
                        self.queryOnce = false
                    }
                    
                    if error == nil {
                        var standData = StandData()
                        
                        if let samples = samples as? [HKCategorySample] {
                            standData.samples = samples
                        }
                        else {
                            standData.samples = []
                        }
    
                        handler(self.entry(complication: complication))
                    }
                }
            }
    
            query.executeSampleQuery(preResultsHandler: preResultsHandler)
        }
        else {
            handler(entry(complication: complication))
        }
    }
    
    private func entry(complication: CLKComplication) -> CLKComplicationTimelineEntry {
        let total = defaults.integer(forKey: DefaultsKey.total.key)
        let hasStoodInCurrentHour = defaults.bool(forKey: DefaultsKey.hasStoodInCurrentHour.key)
        let timeInterval = defaults.double(forKey: DefaultsKey.lastQueryTimeInterval.key)
        let now = Date(timeIntervalSinceReferenceDate: timeInterval)
        
        let template:CLKComplicationTemplate
        let textProvider = CLKSimpleTextProvider(text: String(total))
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
            let imageProvider = CLKImageProvider(onePieceImage: hasStoodInCurrentHour ? #imageLiteral(resourceName: "has stood") : #imageLiteral(resourceName: "not stood"))
            smallFlattemplate.imageProvider = imageProvider
            smallFlattemplate.textProvider = textProvider
        }
        else {
            let smallRingTextTemplate = template as! SmallRingTextTemplateProtocol
            smallRingTextTemplate.ringStyle = .closed
            smallRingTextTemplate.fillFraction = hasStoodInCurrentHour ? 1.0 : 0.5
            smallRingTextTemplate.textProvider = textProvider
        }
        
        let entry = CLKComplicationTimelineEntry(date: now, complicationTemplate: template)
        
        return entry
    }
    
    func getTimelineEntries(for complication: CLKComplication, before date: Date, limit: Int, withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void) {
        // Call the handler with the timeline entries prior to the given date
        handler(nil)
    }
    
    func getTimelineEntries(for complication: CLKComplication, after date: Date, limit: Int, withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void) {
        // Call the handler with the timeline entries after to the given date
        handler(nil)
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
