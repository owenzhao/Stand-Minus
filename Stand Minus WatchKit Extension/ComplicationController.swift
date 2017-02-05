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
import UserNotifications


class ComplicationController: NSObject, CLKComplicationDataSource {
    deinit {
        ComplicationQuery.terminated()
        ComplicationData.terminate()
    }

    private var isFirstStart = true
    private var now:Date! = nil
    
    fileprivate var query:ComplicationQuery? = nil
    
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
        
        switch complication.family {
        case .modularSmall:
            now = Date()
            
            let completeHandler = {
                let data = ComplicationData.shared()
                handler(data.entry!)
            }

            if isFirstStart {
                defer { isFirstStart = false }
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
    
    fileprivate func makeLocalNotificationImmediately() { // if not network, this will notify user
        let center = UNUserNotificationCenter.current()
        if center.delegate == nil { center.delegate = self }
        center.getNotificationSettings { (notificationSettings) in
            let id = UUID().uuidString
            let content = { () -> UNMutableNotificationContent in
                let mc = UNMutableNotificationContent()
                mc.title = NSLocalizedString("Stand Up Notification", comment: "Stand Up Notification Title")
                mc.body = NSLocalizedString("Please stand up and do some activice for one minute", comment: "Stand Up Notification Body")
                
                if notificationSettings.soundSetting == .enabled {
                    mc.sound = UNNotificationSound.default()
                }
                
                return mc
            }()
            let request = UNNotificationRequest(identifier: id, content: content, trigger: nil) // nil means call the trigger immediately
            center.add(request, withCompletionHandler: nil)
        }
    }
    
    /// These methods will no longer be called for clients adopting the WKRefreshBackgroundTask APIs, which are the recommended means of scheduling updates.
    /// In a future release these methods will no longer be called.
    
    /// Return the date when you would next like to be given the opportunity to update your complication content.
    /// We will make an effort to launch you at or around that date, subject to power and budget limitations.
    
    public func getNextRequestedUpdateDate(handler: @escaping (Date?) -> Swift.Void) {
        NSLog("next request update date runs")
        if now == nil { now = Date() }
        
        func calculateNextFireDate() -> Date {
            let data = ComplicationData.shared()
            let cal = Calendar(identifier: .gregorian)
            
            func shouldNotifyUser() -> Bool {
                return data.shouldNotifyUser
            }
            func hasStood() -> Bool {
                return data.hasStood
            }
            func nextWholeHour() -> Date {
                var cps = cal.dateComponents([.year, .month, .day, .hour], from: now)
                cps.hour! += 1
                ExtensionCurrentHourState.shared = .alreadyStood
                
                return cal.date(from: cps)!
            }
            func currentMinute() -> Int {
                return cal.component(.minute, from: now)
            }
            func notifyUser() {
                let center = UNUserNotificationCenter.current()
                if center.delegate == nil { center.delegate = self }
                center.getNotificationSettings { (notificationSettings) in
                    let id = UUID().uuidString
                    let content = { () -> UNMutableNotificationContent in
                        let mc = UNMutableNotificationContent()
                        mc.title = NSLocalizedString("Stand Up Notification", comment: "Stand Up Notification Title")
                        mc.body = NSLocalizedString("Please stand up and do some activice for one minute", comment: "Stand Up Notification Body")
                        
                        if notificationSettings.soundSetting == .enabled {
                            mc.sound = UNNotificationSound.default()
                        }
                        
                        return mc
                    }()
                    let request = UNNotificationRequest(identifier: id, content: content, trigger: nil) // nil means call the trigger immediately
                    center.add(request, withCompletionHandler: nil)
                }
            }
            
            if shouldNotifyUser() || !hasStood() {
                let minute = currentMinute()
                switch minute {
                case 0..<50:
                    var cps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: now)
                    cps.minute = 50
                    let date = cal.date(from: cps)!
                    ExtensionCurrentHourState.shared = .notNotifyUser
                    
                    return date
                default: //(50..<60)
                    if ExtensionCurrentHourState.shared == .notNotifyUser {
                        notifyUser()
                        ExtensionCurrentHourState.shared = .alreadyNotifyUser
                    }
                    return nextWholeHour()
                }
            }
            else {
                return nextWholeHour()
            }
            
        }
        
        let fireDate = calculateNextFireDate()
        
        handler(fireDate)
    }
    
    /// This method will be called when you are woken due to a requested update. If your complication data has changed you can
    /// then call -reloadTimelineForComplication: or -extendTimelineForComplication: to trigger an update.
    
    public func requestedUpdateDidBegin() {
        NSLog("requested update did begin runs")
        now = Date()
        
        query!.start(at: now) { [unowned self] () -> () in
            if self.query!.shouldUpdateComplication {
                let server = CLKComplicationServer.sharedInstance()
                server.activeComplications!.forEach { server.reloadTimeline(for: $0) }
            }
        }
    }
    
    /// This method will be called when we would normally wake you for a requested update but you are out of budget. You can can
    /// trigger one more update at this point (by calling -reloadTimelineForComplication: or -extendTimelineForComplication:) but
    /// this will be the last time you will be woken until your budget is replenished.
    
    public func requestedUpdateBudgetExhausted() {
        NSLog("requested update budget exhausted")
        now = Date()
        
        query!.start(at: now) { [unowned self] () -> () in
            if self.query!.shouldUpdateComplication {
                let server = CLKComplicationServer.sharedInstance()
                server.activeComplications!.forEach { server.reloadTimeline(for: $0) }
            }
        }
    }
    
    func updateComplications() {
        let server = CLKComplicationServer.sharedInstance()
        server.activeComplications?.forEach { server.reloadTimeline(for: $0) }
    }
}

extension ComplicationController:UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert,.sound])
    }
}

enum ExtensionCurrentHourState {
    case notNotifyUser
    case alreadyNotifyUser
    case alreadyStood
    
    static var shared:ExtensionCurrentHourState = .notNotifyUser
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
    
//    class func invalidate() -> ComplicationData {
//        instance = nil
//        return shared()
//    }
    
    class func terminate() {
        instance = nil
    }
    
    private var _samples:[HKCategorySample] = []
    private var _stoodCount = 0
    private var _hasStood = false
    private let cal = Calendar(identifier: .gregorian)
    
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
    
    private var isFirstQuery = true
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
    
    private func dayOf(_ date:Date) -> Int {
        return cal.component(.day, from: date)
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
                    let data = ComplicationData.shared()
                    
                    defer {
                        self.anchor = nextAnchor
                        if self._shouldUpdateComplication {
                            let data = ComplicationData.shared()
                            data.update(at: now)
                        }
                        completeHandler()
                        self._shouldUpdateComplication = false
                    }
                    
                    if self.isFirstQuery {
                        defer {
                            self._shouldUpdateComplication = true
                            self.isFirstQuery = false
                        }
                        
//                        let data = ComplicationData.invalidate()
                        data.assign(samples as! [HKCategorySample])
                    }
                    else {
                        if let deletedObjects = deletedObjects, !deletedObjects.isEmpty {
                            data.delete(deletedObjects)
                            self._shouldUpdateComplication = true
                        }
                        if let samples = samples as? [HKCategorySample] {
                            data.append(samples)
                            self._shouldUpdateComplication = true
                        }
                    }
                }
            }
        }
        
        if isFirstQuery || (dayOf(lastQueryDate!) != dayOf(now))
        {
            defer { isFirstQuery = true }
            
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
