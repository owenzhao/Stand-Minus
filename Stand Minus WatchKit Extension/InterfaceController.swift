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
    private lazy var defaults = UserDefaults.standard
    private lazy var store = HKHealthStore()
    private lazy var query = StandHourQuery()
    
    private var hasComplication:Bool {
        if let _ = CLKComplicationServer.sharedInstance().activeComplications {
            return true
        }
        
        return false
    }
    
    var hasStood:Bool? {
        return defaults.object(forKey: DefaultsKey.hasStoodInCurrentHour.key) as? Bool
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
    @IBOutlet var complicationsLabel: WKInterfaceLabel!
    
    @IBAction func updateButtonClicked() {
        queryCurrentStandUpInfo()
    }
    
    private func queryCurrentStandUpInfo() {        
        let resultHandler:HKSampleQuery.ResultsHandler = { [unowned self] (_, samples, error) in
            if error == nil {
                var standData = StandData()
                
                if let samples = samples as? [HKCategorySample] {
                    standData.samples = samples
                } else {
                    standData.samples = []
                }
                
                DispatchQueue.main.async { [unowned self] in
                    self.updateUI()
                }
                
                if self.hasComplication {
                    self.updateComplications()
                }
            }
        }
        
        query.executeSampleQuery(resultsHandler: resultHandler)
    }
    
    private func updateComplications() {
        let server = CLKComplicationServer.sharedInstance()
        server.activeComplications!.forEach { server.reloadTimeline(for: $0) }
    }
    
    func updateUI() {
        lastQueryDateLabel.setText(self.localizedLastQueryDate())
        hasStoodLabel.setText(self.localizedLabelOfHasStood())
        
        // FIXME: Xcode 9 beta 5 can't solve statement ? s1 : s2 correctly.
        let complicationLabelText:String = {
            if hasComplication {
                return NSLocalizedString("Has", comment: "Has")
            }
            
            return NSLocalizedString("None", comment: "None")
        }()
        
        complicationsLabel.setText(complicationLabelText)
    }
    
    private func localizedLabelOfHasStood() -> String {
        if let hasStood = self.hasStood {
            if hasStood {
                return NSLocalizedString("Already stood", comment: "Already stood")
            }
            
            return NSLocalizedString("Not stood yet", comment: "Not stood yet.")
        }
        
        return NSLocalizedString("Unknown", comment: "Unknown")
    }
    
    private func localizedLastQueryDate() -> String {
        if let lastQueryTimeIntervalSinceReferenceDate = defaults.object(forKey: DefaultsKey.lastQueryTimeInterval.key) as? Double {
            let lastQueryDate = Date(timeIntervalSinceReferenceDate: lastQueryTimeIntervalSinceReferenceDate)
            
            return DateFormatter.localizedString(from: lastQueryDate, dateStyle: .none, timeStyle: .medium)
        }
        
        return NSLocalizedString("Not Query yet.", comment: "Not Query yet.")
    }
}
