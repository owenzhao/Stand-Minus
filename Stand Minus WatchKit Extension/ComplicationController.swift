//
//  ComplicationController.swift
//  Stand Minus WatchKit Extension
//
//  Created by 肇鑫 on 2017-1-31.
//  Copyright © 2017年 ParusSoft.com. All rights reserved.
//

import ClockKit
import WatchKit

class ComplicationController: NSObject, CLKComplicationDataSource {
    deinit {
        StandHourQuery.terminate()
        CurrentHourData.terminate()
    }

    unowned private let data = CurrentHourData.shared()
    
    private let query = StandHourQuery.shared()
    
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
        // NSLog("complication updates")
        let now = Date()
        
        func entryOf(_ complication:CLKComplication) -> CLKComplicationTimelineEntry {
            let template:CLKComplicationTemplate
            let textProvider = CLKSimpleTextProvider(text: String(self.data.stoodCount))
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
                let imageProvider = CLKImageProvider(onePieceImage: self.data.hasStood ? #imageLiteral(resourceName: "has stood") : #imageLiteral(resourceName: "not stood"))
                smallFlattemplate.imageProvider = imageProvider
                smallFlattemplate.textProvider = textProvider
            }
            else {
                let smallRingTextTemplate = template as! SmallRingTextTemplateProtocol
                smallRingTextTemplate.ringStyle = .closed
                smallRingTextTemplate.fillFraction = self.data.hasStood ? 1.0 : 0.5
                smallRingTextTemplate.textProvider = textProvider
            }
            
            return CLKComplicationTimelineEntry(date: now, complicationTemplate: template)
        }
        
        if query.by == .backgroundTask || WKExtension.shared().applicationState == .active { // app calls complication updates
            handler(entryOf(complication))
        }
        else {
            let delegate = WKExtension.shared().delegate as! ExtensionDelegate
//            delegate.fireDates.append(now)
            delegate.fireDate = now
            
            delegate.procedureStart(by: .complicationDirectly, at: now, updateOwenComplication: true) {
                handler(entryOf(complication))
            }
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
            let provider = CLKSimpleTextProvider(text: "-")
            let template = CLKComplicationTemplateModularSmallRingText()
            template.textProvider = provider
            
            handler(template)
        default:
            handler(nil)
        }
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
