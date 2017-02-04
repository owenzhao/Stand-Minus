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
import WatchConnectivity


class ComplicationController: NSObject, CLKComplicationDataSource {
    deinit {
        ComplicationQuery.terminated()
        ComplicationData.terminate()
    }
//    var now = Date()
//    let cal = Calendar(identifier: .gregorian)
//    var cps:DateComponents? = nil
//    var midNight:Date? = nil
    fileprivate var query:ComplicationQuery? = nil
    
    private let session = WCSession.default()
    fileprivate var handler:(()->())? = nil
    
    // MARK: - Timeline Configuration
    
    func getSupportedTimeTravelDirections(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimeTravelDirections) -> Void) {
        handler([])
    }
    
    func getTimelineStartDate(for complication: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
//        cps = cal.dateComponents([.year, .month, .day], from: now)
//        midNight = cal.date(from: cps!)!
//        
//        handler(midNight)
        handler(nil)
    }
    
    func getTimelineEndDate(for complication: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
//        handler(midNight!.addingTimeInterval(60 * 60 * 24))
        handler(nil)
    }
    
    func getPrivacyBehavior(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationPrivacyBehavior) -> Void) {
        handler(.hideOnLockScreen)
    }
    
    // MARK: - Timeline Population
    
    func getCurrentTimelineEntry(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void) {
        // Call the handler with the current timeline entry
        NSLog("complication updates")
        
        if session.delegate == nil {
            session.delegate = self
            session.activate()
        }
        
        switch complication.family {
        case .modularSmall:
            let now = Date()
            
            let completeHandler = {
                let data = ComplicationData.shared()
                handler(data.entry!)
            }
            
            if query == nil {
                query = ComplicationQuery.shared()
                
                query!.start(at: now, completeHandler: completeHandler)
            }
            else {
                completeHandler()
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
            let provider = CLKSimpleTextProvider(text: "-")
            let template = CLKComplicationTemplateModularSmallRingText()
            template.textProvider = provider
            
            handler(template)
        default:
            handler(nil)
        }
    }
    
    /// These methods will no longer be called for clients adopting the WKRefreshBackgroundTask APIs, which are the recommended means of scheduling updates.
    /// In a future release these methods will no longer be called.
    
    /// Return the date when you would next like to be given the opportunity to update your complication content.
    /// We will make an effort to launch you at or around that date, subject to power and budget limitations.
    
    public func getNextRequestedUpdateDate(handler: @escaping (Date?) -> Swift.Void) {
        NSLog("next request update date runs")
        let now = Date()
        let fireDate:Date
        
        var cps = cal.dateComponents([.year, .month, .day, .hour], from: now)
        
        func nextWholeHour() {
            cps.hour! += 1
            let fireDate = cal.date(from: cps)!
            self.handler = {
                self.session.sendMessage(["whole hour notification":fireDate], replyHandler: nil, errorHandler: nil)
            }
            if self.session.activationState == .activated {
                self.handler?()
            }
            else {
                self.session.activate()
            }
            
            NSLog("next whole hour runs.")
            
            handler(fireDate)
        }
        
        func makeLocalNotificationImmediately() {
            
        }
        
        let data = ComplicationData.shared()
        if data.hasStood {
            nextWholeHour()
        }
        else {
            let minute = cal.component(.minute, from: now)
            switch minute {
            case 0..<30:
                cps.minute = 30
                let fireDate = cal.date(from: cps)!
                handler(fireDate)
            case 30..<50:
                if data.shouldNotifyUser && ExtensionCurrentHourState.shared == .notArrangeRemoteNotification {
                    cps.minute = 50
                    fireDate = cal.date(from: cps)!
                    self.handler = {
                        self.session.sendMessage(["notify user":fireDate], replyHandler: nil, errorHandler: nil)
                        ExtensionCurrentHourState.shared = .alreadySetNotification
                    }
                    if self.session.activationState == .activated {
                        self.handler?()
                    }
                    handler(fireDate)
                }
                else {
                    nextWholeHour()
                }
            case 50..<60:
                if data.shouldNotifyUser && ExtensionCurrentHourState.shared != .alreadyNotifiedUser {
                    makeLocalNotificationImmediately()
                    ExtensionCurrentHourState.shared = .alreadyNotifiedUser
                }
                
                nextWholeHour()
            default:
                fatalError()
            }
        }
    }
    
    /// This method will be called when you are woken due to a requested update. If your complication data has changed you can
    /// then call -reloadTimelineForComplication: or -extendTimelineForComplication: to trigger an update.
    
    public func requestedUpdateDidBegin() {
        NSLog("requested update did begin runs")
        let now = Date()
        if query == nil {
            query = ComplicationQuery.shared()
        }
        
        query!.start(at: now) { [unowned self] () -> () in
            if self.query!.shouldUpdateComplication {
                let server = CLKComplicationServer.sharedInstance()
                server.activeComplications?.forEach { server.reloadTimeline(for: $0) }
            }
        }
    }
    
    /// This method will be called when we would normally wake you for a requested update but you are out of budget. You can can
    /// trigger one more update at this point (by calling -reloadTimelineForComplication: or -extendTimelineForComplication:) but
    /// this will be the last time you will be woken until your budget is replenished.
    
    public func requestedUpdateBudgetExhausted() {
        NSLog("requested update budget exhausted")
        let now = Date()
        query!.start(at: now) { [unowned self] () -> () in
            if self.query!.shouldUpdateComplication {
                let server = CLKComplicationServer.sharedInstance()
                server.activeComplications?.forEach { server.reloadTimeline(for: $0) }
            }
        }
    }
    
    // MARK: - notify user
    func notifyUser() {
        
    }
    
    func updateComplications() {
        let server = CLKComplicationServer.sharedInstance()
        server.activeComplications?.forEach { server.reloadTimeline(for: $0) }
    }
}

extension ComplicationController: WCSessionDelegate {
    
    /** Called when the session has completed activation. If session state is WCSessionActivationStateNotActivated there will be an error with more details. */
    
    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        guard error == nil else { fatalError(error!.localizedDescription) }
        if session.activationState == .activated {
            self.handler?()
            handler = nil
        }
    }
    
    
    /** ------------------------- Interactive Messaging ------------------------- */
    
    /** Called when the reachable state of the counterpart app changes. The receiver should check the reachable property on receiving this delegate callback. */
    public func sessionReachabilityDidChange(_ session: WCSession) {
        
    }
    
    
    /** Called on the delegate of the receiver. Will be called on startup if the incoming message caused the receiver to launch. */
    public func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        if let key = message.keys.first, let date = message.values.first as? Date {
            if key == "whole hour notification" {
                query?.start(at: date, completeHandler: { 
                    self.updateComplications()
                    ExtensionCurrentHourState.shared = .notArrangeRemoteNotification
                })
            }
            else if key == "notify user" {
                query?.start(at: date, completeHandler: { 
                    let data = ComplicationData.shared()
                    if !data.hasStood {
                        self.notifyUser()
                    }
                    self.updateComplications()
                    ExtensionCurrentHourState.shared = .alreadyNotifiedUser
                })
            }
        }
    }
}

let cal = Calendar(identifier: .gregorian)
//func logPrint(_ text:String) {
//    let now = Date()
//    print("\(DateFormatter.localizedString(from: now, dateStyle: .medium, timeStyle: .medium)): \(text)")
//}

enum ExtensionCurrentHourState {
    case notArrangeRemoteNotification
    case alreadySetNotification
    case alreadyNotifiedUser
    
    static var shared:ExtensionCurrentHourState = .notArrangeRemoteNotification
}

class ComplicationData {
    private static var instance:ComplicationData? = nil
    
    private init() { }
    
    class func shared() -> ComplicationData {
        if instance == nil {
            instance = ComplicationData()
        }
        
        return instance!
    }
    
    class func invalidate() -> ComplicationData {
        instance = nil
        return shared()
    }
    
    class func terminate() {
        instance = nil
    }
    
    private var _samples:[HKCategorySample] = []
    private var _stoodCount = 0
    private var _hasStood = false
    
    var sample:[HKCategorySample]? {
        return _samples
    }
    var stoodCount:Int {
        return _stoodCount
    }
    var hasStood:Bool {
        return _hasStood
    }
    var shouldNotifyUser:Bool {
        return _stoodCount >= 12
    }
    
    func delete(_ deletedObjects:[HKDeletedObject]) {
        for d in deletedObjects {
            for s in _samples {
                if d.uuid == s.uuid, let index = _samples.index(of: s) {
                    _samples.remove(at: index)
                }
            }
        }
    }
    
    func append(_ samples:[HKCategorySample]) {
        _samples.append(contentsOf: samples)
    }
    
    func assign(_ samples:[HKCategorySample]) {
        _samples = samples
    }
    
    func update(at now:Date) {
        func hourOf(_ date:Date) -> Int {
            return cal.component(.hour, from: date)
        }
        
        func stoodCount() {
            _stoodCount = _samples.reduce(0, { (result, nextSample) -> Int in
                let value = (nextSample.value == HKCategoryValueAppleStandHour.stood.rawValue ? 1 : 0)
                return result + value
            })
        }
        
        func hasStood() {
            if let latestSample = (_samples.max { $0.0.startDate < $0.1.startDate }) {
                let hourInLast = hourOf(latestSample.startDate)
                let hourNow = hourOf(now)
                
                _hasStood = hourInLast == hourNow
            }
            else {
                _hasStood = false
            }
        }
        
        stoodCount()
        hasStood()
        
        updateEntry(at: now)
    }
    
    // MARK: - entry
    private var _entry: CLKComplicationTimelineEntry? = nil
    var entry: CLKComplicationTimelineEntry? {
        return _entry
    }
    
    func updateEntry(at now:Date) {
        let provider = CLKSimpleTextProvider(text: String(_stoodCount))
        let template = CLKComplicationTemplateModularSmallRingText()
        template.ringStyle = .closed
        template.fillFraction = _hasStood ? 1.0 : 0.5
        template.textProvider = provider
        
        _entry = CLKComplicationTimelineEntry(date: now, complicationTemplate: template)
    }
}

class ComplicationQuery {
    private static var instance:ComplicationQuery? = nil
    
    private init() { }
    
    class func shared() -> ComplicationQuery {
        if instance == nil { instance = ComplicationQuery() }
        return instance!
    }
    
    class func terminated() {
        instance = nil
    }
    
    private var anchor:HKQueryAnchor? = nil
    
    private var lastQueryDate:Date! = nil
    private var predicate:NSPredicate! = nil
    private var anchorQuery:HKAnchoredObjectQuery! = nil
    
    private let cal = Calendar(identifier: .gregorian)
    private let sampleType = HKObjectType.categoryType(forIdentifier: .appleStandHour)!
    private let store = HKHealthStore()
    
    private var _shouldUpdateComplication = false
    
    var shouldUpdateComplication:Bool {
        return _shouldUpdateComplication
    }
    
    private func hourOf(_ date:Date) -> Int {
        return cal.component(.hour, from: date)
    }
    
    func start(at now:Date, completeHandler: @escaping () -> ()) {
        func createPredicate() {
            let cps = cal.dateComponents([.year, .month, .day], from: now)
            let midnight = cal.date(from: cps)!
            
            predicate = HKQuery.predicateForSamples(withStart: midnight, end: midnight.addingTimeInterval(24 * 60 * 60), options: .strictStartDate)
        }
        
        func creatAnchorQuery() {
            anchorQuery = HKAnchoredObjectQuery(type: sampleType, predicate: predicate, anchor: anchor, limit: HKObjectQueryNoLimit) { [unowned self] (query, samples, deletedObjects, nextAnchor, error) -> Void in
                if error == nil {
                    defer {
                        self.anchor = nextAnchor
                        completeHandler()
                        self._shouldUpdateComplication = false
                    }
                    
                    if self.anchor == nil {
                        defer { self._shouldUpdateComplication = true }
                        
                        let data = ComplicationData.invalidate()
                        data.assign(samples as! [HKCategorySample])
                        data.update(at: now)
                    }
                    else {
                        let data = ComplicationData.shared()
                        
                        if let deletedObjects = deletedObjects, !deletedObjects.isEmpty {
                            data.delete(deletedObjects)
                            self._shouldUpdateComplication = true
                        }
                        if let samples = samples as? [HKCategorySample] {
                            data.append(samples)
                            if !self._shouldUpdateComplication { self._shouldUpdateComplication = true }
                        }
                        
                        if self._shouldUpdateComplication { data.update(at: now) }
                    }
                }
            }
        }
        
        if anchor == nil
            || (lastQueryDate != nil && hourOf(lastQueryDate!) != hourOf(now))
            || predicate == nil
            || anchorQuery == nil
        {
            lastQueryDate = now
            anchor = nil
            
            createPredicate()
        }
        
        creatAnchorQuery()
        
        store.requestAuthorization(toShare: nil, read: [sampleType]) { [unowned self] (success, error) in
            if error == nil && success {
                self.store.execute(self.anchorQuery!)
            }
        }
    }
}
