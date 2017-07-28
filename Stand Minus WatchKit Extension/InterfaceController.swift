//
//  InterfaceController.swift
//  Stand Minus WatchKit Extension
//
//  Created by 肇鑫 on 2017-1-31.
//  Copyright © 2017年 ParusSoft.com. All rights reserved.
//

import WatchKit
import Foundation
import ClockKit
import HealthKit

class InterfaceController: WKInterfaceController {
    private lazy var delegate = WKExtension.shared().delegate as! ExtensionDelegate
    private let defaults = UserDefaults.standard
    private lazy var store = HKHealthStore()
    private unowned let todayStandData = TodayStandData.shared()
    private unowned let query = StandHourQuery.shared()
    
    var hasStood:Bool? {
        return defaults.object(forKey: DefaultsKey.hasStoodKey) as? Bool
    }
    
    
    private func addMeneItemOfUpdate() {
        return addMenuItem(with: .resume, title: NSLocalizedString("Update", comment: "Update"), action: #selector(updateButtonClicked))
    }
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        addMeneItemOfUpdate()
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        
        updateUI()
    }

    // MARK: - UI
    
    @IBOutlet var hasStoodLabel: WKInterfaceLabel!
    @IBOutlet var lastQueryDateLabel: WKInterfaceLabel!
    
    @IBAction func updateButtonClicked() {
        queryCurrentStandUpInfo()
    }
    
    private func queryCurrentStandUpInfo() {
        let type = HKObjectType.categoryType(forIdentifier: .appleStandHour)!
        
        let now = Date()
        let c = Calendar(identifier: .gregorian)
        var cps = c.dateComponents([.year, .month, .day,], from: now)
        let zeroHour = c.date(from: cps)
        cps.hour! += 24
        let midnight = c.date(from: cps)

        let predicate = HKQuery.predicateForSamples(withStart: zeroHour, end: midnight, options: [.strictStartDate])
        
        let soreDescrptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [soreDescrptor]) { [unowned self] (_, samples, error) in
            
            guard error == nil else {
                fatalError(error!.localizedDescription)
            }
            
            if let samples = samples as? [HKCategorySample], let lastSample = samples.last {
                let total = samples.reduce(0) { (result, sample) -> Int in
                    result + (1 - sample.value)
                }
                
                var hassStoodInCurrentHour = false
                
                if lastSample.value == HKCategoryValueAppleStandHour.stood.rawValue {
                    let currentHour = c.component(.hour, from: now)
                    let lastSampleHour = c.component(.hour, from: lastSample.startDate)
                    hassStoodInCurrentHour = (currentHour == lastSampleHour)
                }
                
                self.todayStandData.explicitlySetTotal(total)
                self.todayStandData.explicitlySetHasStoodInCurrentHour(hassStoodInCurrentHour)
            } else {
                self.todayStandData.explicitlySetTotal(0)
                self.todayStandData.explicitlySetHasStoodInCurrentHour(false)
            }
            
            self.updateUI()
            
            let hasComplication:Bool = {
                if let _ = CLKComplicationServer.sharedInstance().activeComplications {
                    return true
                }
                
                return false
            }()
            
            if hasComplication {
                self.updateComplications()
            }
            
            self.query.arrangeNextBackgroundTask(at: now, hasComplication: hasComplication)
        }
        
        defaults.removeObject(forKey: DefaultsKey.hasStoodKey)
        defaults.set(now.timeIntervalSinceReferenceDate, forKey:DefaultsKey.lastQueryTimeIntervalSinceReferenceDateKey)
        
        store.execute(query)
    }
    
    private func updateComplications() {
        let server = CLKComplicationServer.sharedInstance()
        server.activeComplications!.forEach { server.reloadTimeline(for: $0) }
    }
    
    typealias CompletiongHandler = () -> ()
    
    func updateUI(completionHandler: @escaping () -> () = { }) {
        DispatchQueue.main.async { [unowned self] in
            self.lastQueryDateLabel.setText(self.localizedLastQueryDate())
            self.hasStoodLabel.setText(self.localizedLabelOfHasStood())
            
            completionHandler()
        }
    }
    
    private func localizedLabelOfHasStood() -> String {
        if let hasStood = self.hasStood {
            if hasStood {
                return NSLocalizedString("Already stood", comment: "Already stood")
            }
            
            return NSLocalizedString("Not stood yet", comment: "Not stood yet.")
        }
        
        return NSLocalizedString("Watch Locked", comment: "Watch Locked")
    }
    
    private func localizedLastQueryDate() -> String {
        let lastQueryTimeIntervalSinceReferenceDate = defaults.double(forKey: DefaultsKey.lastQueryTimeIntervalSinceReferenceDateKey)
        let lastQueryDate = Date(timeIntervalSinceReferenceDate: lastQueryTimeIntervalSinceReferenceDate)
        
        return DateFormatter.localizedString(from: lastQueryDate, dateStyle: .none, timeStyle: .medium)
    }
}
