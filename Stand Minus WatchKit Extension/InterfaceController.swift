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
            
        DispatchQueue.main.asyncAfter(wallDeadline: .now()) { [unowned self] in
            if self.query.hasComplication {
                self.queryCurrentStandUpInfo()
            }
        }
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
        let preResultsHandler:HKSampleQuery.PreResultsHandler = { [unowned self] (now, hasComplication) -> HKSampleQuery.ResultsHandler in
            return { [unowned self] (_, samples, error) in
//                guard error == nil else {
//                    fatalError(error!.localizedDescription)
//                }
//
//                if let samples = samples as? [HKCategorySample] {
//                    self.todayStandData.samples = samples
//                } else {
//                    self.todayStandData.samples = []
//                }
//
//                DispatchQueue.main.async { [unowned self] in
//                    self.updateUI()
//                }
//
//                if hasComplication {
//                    self.updateComplications()
//                }
//
//                self.query.arrangeNextBackgroundTask(at: now, hasComplication: hasComplication)
//
                if error == nil {
                    if let samples = samples as? [HKCategorySample] {
                        self.todayStandData.samples = samples
                    } else {
                        self.todayStandData.samples = []
                    }
                    
                    if hasComplication {
                        self.updateComplications()
                    }
                    
                    self.query.arrangeNextBackgroundTask(at: now, hasComplication: hasComplication)
                }
                else { // device is locked. **query failed, reason: Protected health data is inaccessible**
                    self.query.arrangeNextBackgroundTaskWhenDeviceIsLocked(at: now, hasComplication: hasComplication)
                }
            }
        }
        
        query.executeSampleQuery(preResultsHandler: preResultsHandler)
    }
    
    private func updateComplications() {
        let server = CLKComplicationServer.sharedInstance()
        server.activeComplications!.forEach { server.reloadTimeline(for: $0) }
    }
    
    func updateUI() {
        lastQueryDateLabel.setText(self.localizedLastQueryDate())
        hasStoodLabel.setText(self.localizedLabelOfHasStood())
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
