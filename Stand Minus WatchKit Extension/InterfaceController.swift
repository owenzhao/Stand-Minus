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

class InterfaceController: WKInterfaceController {
    private lazy var delegate = WKExtension.shared().delegate as! ExtensionDelegate
    private let defaults = UserDefaults.standard
    
    var hasStood:Bool? {
        let isDefaultsContainHasStood = !(defaults.object(forKey: DefaultsKey.hasStoodKey) == nil)
        
        return isDefaultsContainHasStood ? defaults.bool(forKey: DefaultsKey.hasStoodKey) : nil
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
//        updateUI()
    }

    // MARK: - UI
    
    @IBOutlet var hasStoodLabel: WKInterfaceLabel!
    @IBOutlet var lastQueryDateLabel: WKInterfaceLabel!
    
    @IBAction func updateButtonClicked() {
        queryCurrentStandUpInfo()
    }
    
    // MARK: - private functions
    
    /// When Apple Watch reboots, complication and interface will rerun at the same time.
    /// In order to solve the problem, I used semaphore to keep one query runs at one time.
    /// Since main thread shouldn't be blocked, the `DispatchQueue.global()` queue is necessary.
    /// There was also very rare possibility and when you manually update UI in Watch app, the background task runs.
    private func queryCurrentStandUpInfo() {
        DispatchQueue.global().async { [unowned self] in
            let now = Date()
            self.defaults.set(now.timeIntervalSinceReferenceDate, forKey:DefaultsKey.lastQueryTimeIntervalSinceReferenceDateKey)
            self.delegate.startProcedure(at: now) {[unowned self] in // run first time after reboot
                DispatchQueue.main.async { [unowned self] in
                    self.updateUI()
                }
            }
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
