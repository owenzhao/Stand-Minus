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
    
    var hasStood:Bool? = nil
    var fireDate:Date! = nil
    
    private func addMeneItemOfUpdate() {
        return addMenuItem(with: .resume, title: NSLocalizedString("Update", comment: "Update"), action: #selector(updateButtonClicked))
    }
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        addMeneItemOfUpdate()
        queryCurrentStandUpInfo()
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        updateUI()
    }

    // MARK: - UI
    
    @IBOutlet var hasStoodLabel: WKInterfaceLabel!
    @IBOutlet var fireDateLabel: WKInterfaceLabel!
    
    @IBAction func updateButtonClicked() {
        queryCurrentStandUpInfo()
    }
    
    // MARK: - private functions
    private func queryCurrentStandUpInfo() {
        let now = Date()
        fireDate = now
        StandHourQuery.shared().complicationShouldReQuery = false
        delegate.startProcedure(at: now) {[unowned self] in // run first time after reboot
            self.updateUI()
        }
    }
    
    private func updateUI() {
        func localizedLabelOfHasStood() -> String {
            guard let hasStood = hasStood else {
                return NSLocalizedString("Watch Locked", comment: "Watch Locked")
            }
            
            if hasStood {
                return NSLocalizedString("Already stood", comment: "Already stood")
            }
            
            return NSLocalizedString("Not stood yet", comment: "Not stood yet.")
        }
        
        func localizedFireDate() -> String {
            return DateFormatter.localizedString(from: fireDate, dateStyle: .none, timeStyle: .medium)
        }
        
        fireDateLabel.setText(localizedFireDate())
        hasStoodLabel.setText(localizedLabelOfHasStood())
    }
}
