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
        
        defaults.addObserver(self, forKeyPath: DefaultsKey.lastQueryTimeIntervalSinceReferenceDateKey, options: .new, context: nil)
        defaults.addObserver(self, forKeyPath: DefaultsKey.hasStoodKey, options: .new, context: nil)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        DispatchQueue.main.async { [unowned self] in
            self.updateUI()
        }
    }
    
    override func willDisappear() {
        defaults.removeObserver(self, forKeyPath: DefaultsKey.lastQueryTimeIntervalSinceReferenceDateKey)
        defaults.removeObserver(self, forKeyPath: DefaultsKey.hasStoodKey)
    }

    // MARK: - UI
    
    @IBOutlet var hasStoodLabel: WKInterfaceLabel!
    @IBOutlet var lastQueryDateLabel: WKInterfaceLabel!
    
    @IBAction func updateButtonClicked() {
        queryCurrentStandUpInfo()
    }
    
    private func queryCurrentStandUpInfo() {
        let preResultsHander:HKSampleQuery.PreResultsHandler = { [unowned self] (now, hasComplication) -> HKSampleQuery.ResultsHandler in
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
                
                
                DispatchQueue.main.async { [unowned self] in
                    self.updateUI()
                }
                
                if hasComplication {
                    self.updateComplications()
                }
                
                self.query.arrangeNextBackgroundTask(at: now, hasComplication: hasComplication)
            }
        }
        
        self.query.executeSampleQuery(preResultsHandler: preResultsHander)
    }
    
    private func updateComplications() {
        let server = CLKComplicationServer.sharedInstance()
        server.activeComplications!.forEach { server.reloadTimeline(for: $0) }
    }
    
    func updateUI() {
        self.lastQueryDateLabel.setText(self.localizedLastQueryDate())
        self.hasStoodLabel.setText(self.localizedLabelOfHasStood())
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
