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
        let cps = c.dateComponents([.year, .month, .day, .hour], from: now)
        let currentHour = c.date(from: cps)

        let predicate = HKQuery.predicateForSamples(withStart: currentHour, end: nil, options: [.strictStartDate])
        
        let soreDescrptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [soreDescrptor]) { [unowned self] (_, samples, error) in
            
            guard error == nil else {
                fatalError(error!.localizedDescription)
            }
            
            var hasStood = false
            
            if  let samples = samples {
                hasStood = !samples.isEmpty
            }
            
            self.defaults.set(hasStood, forKey: DefaultsKey.hasStoodKey)
            self.updateUI()
            self.updateComplications()
        }
        
        defaults.removeObject(forKey: DefaultsKey.hasStoodKey)
        defaults.set(now.timeIntervalSinceReferenceDate, forKey:DefaultsKey.lastQueryTimeIntervalSinceReferenceDateKey)
        
        store.execute(query)
    }
    
    private func updateComplications() {
        let server = CLKComplicationServer.sharedInstance()
        if let _ = server.activeComplications {
            server.activeComplications!.forEach { server.reloadTimeline(for: $0) }
        }
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
