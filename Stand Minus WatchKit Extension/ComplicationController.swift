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
    static let complicationWillUpdate = Notification.Name("complicationWillUpdate")
    
    private var queryOnce:Bool = true

    private lazy var query = StandHourQuery()
    private lazy var defaults = UserDefaults.standard
    
    func getComplicationDescriptors(handler: @escaping ([CLKComplicationDescriptor]) -> Void) {
        let supportedFamilies:[CLKComplicationFamily] = [
            .circularSmall,
            .modularSmall,
            .utilitarianSmall,
            .utilitarianSmallFlat,
            .graphicCorner,
            .graphicCircular,
        ]
        
        let standDescriptor = CLKComplicationDescriptor(identifier: "stand minus", displayName: "Stand Minus", supportedFamilies: supportedFamilies)
        
        handler([standDescriptor])
    }
    
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
            let resultHandler:HKSampleQuery.ResultsHandler = { [unowned self] (_, samples, error) in
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

                    
                    NotificationCenter.default.post(name: ComplicationController.complicationWillUpdate, object: nil)
                    handler(self.entry(complication: complication))
                }
            }
            
            query.executeSampleQuery(resultsHandler: resultHandler)
        }
        else {
            NotificationCenter.default.post(name: ComplicationController.complicationWillUpdate, object: nil)
            handler(entry(complication: complication))
        }
    }
    
    private func entry(complication: CLKComplication) -> CLKComplicationTimelineEntry {
        let total = defaults.integer(forKey: DefaultsKey.total.key)
        let hasStoodInCurrentHour = defaults.bool(forKey: DefaultsKey.hasStoodInCurrentHour.key)
        let left:Int, right:Int
        
        if hasStoodInCurrentHour {
            left = total - 1
            right = total
        } else {
            left = total
            right = total + 1
        }
        
        let timeInterval = defaults.double(forKey: DefaultsKey.lastQueryTimeInterval.key)
        let now = Date(timeIntervalSinceReferenceDate: timeInterval)
        
        let textProvider:CLKTextProvider = {
            let tp = CLKSimpleTextProvider(text: String(total))
            tp.tintColor = hasStoodInCurrentHour ? .red : .green
            
            return tp
        }()
        
        let template:CLKComplicationTemplate = {
            switch complication.family {
            case .circularSmall:
                return CLKComplicationTemplateCircularSmallRingText(textProvider: textProvider,
                                                                    fillFraction: hasStoodInCurrentHour ? 1.0 : 0.5,
                                                                    ringStyle: .closed)
            case .extraLarge:
                fatalError("doesn't do this")
            case .modularSmall:
                return CLKComplicationTemplateModularSmallRingText(textProvider: textProvider,
                                                                   fillFraction: hasStoodInCurrentHour ? 1.0 : 0.5,
                                                                   ringStyle: .closed)
            case .modularLarge:
                fatalError("doesn't do this")
            case .utilitarianSmall:
                fallthrough
            case .utilitarianSmallFlat:
                let imageProvider = CLKImageProvider(onePieceImage: hasStoodInCurrentHour ? #imageLiteral(resourceName: "has stood") : #imageLiteral(resourceName: "not stood"))
                return CLKComplicationTemplateUtilitarianSmallFlat(textProvider: textProvider,
                                                                   imageProvider: imageProvider)
            case .utilitarianLarge:
                fatalError("doesn't do this")
            case .graphicCorner:
                let outerTextProvider = CLKRelativeDateTextProvider(date: now, style: .offsetShort, units: [.hour, .minute, .second])
                let leadingTextProvider:CLKTextProvider =  {
                    let tp = CLKSimpleTextProvider(text: String(left))
                    tp.tintColor = .red
                    
                    return tp
                }()
                
                let trailingTextProvider:CLKTextProvider = {
                    let tp = CLKSimpleTextProvider(text: String(right))
                    tp.tintColor = hasStoodInCurrentHour ? .red : .green
                    
                    return tp
                }()

                let gaugeProvider = hasStoodInCurrentHour ? CLKSimpleGaugeProvider(style: .fill, gaugeColor: .green, fillFraction: 1.0) : CLKSimpleGaugeProvider(style: .ring, gaugeColors: [.red, .green], gaugeColorLocations: [0.0, 1.0], fillFraction: 0.5)
                

                return CLKComplicationTemplateGraphicCornerGaugeText(gaugeProvider: gaugeProvider,
                                                                     leadingTextProvider: leadingTextProvider,
                                                                     trailingTextProvider: trailingTextProvider,
                                                                     outerTextProvider: outerTextProvider)
            case .graphicCircular:
                let gaugeProvider = hasStoodInCurrentHour ? CLKSimpleGaugeProvider(style: .fill, gaugeColor: .green, fillFraction: 1.0) : CLKSimpleGaugeProvider(style: .fill, gaugeColors: [.red, .green], gaugeColorLocations: [0.0, 1.0], fillFraction: 1.0)
                return CLKComplicationTemplateGraphicCircularClosedGaugeText(gaugeProvider: gaugeProvider,
                                                                             centerTextProvider: textProvider)
            case .graphicBezel:
                fatalError("doesn't do this")
            case .graphicRectangular:
                fatalError("doesn't do this")
            default: // utilitarianSmall
                fatalError("doesn't do this")
            }
        }()
        
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

protocol SmallRingTextTemplateProtocol:AnyObject {
    var textProvider: CLKTextProvider { get set }
    var ringStyle: CLKComplicationRingStyle { get set }
    var fillFraction: Float { get set }
}

//extension CLKComplicationTemplateExtraLargeRingText: SmallRingText {} // won't use now, as it can't show realtime results
extension CLKComplicationTemplateModularSmallRingText: SmallRingTextTemplateProtocol {}
extension CLKComplicationTemplateCircularSmallRingText: SmallRingTextTemplateProtocol {}
extension CLKComplicationTemplateUtilitarianSmallRingText: SmallRingTextTemplateProtocol {}
