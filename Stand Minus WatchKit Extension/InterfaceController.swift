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
//    unowned private let data = CurrentHourData.shared()
    
    var hasStood:Bool? = nil
    var fireDate:Date! = nil
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        addMenuItem(with: .resume, title: NSLocalizedString("Update", comment: "Update"), action: #selector(updateButtonClicked))
        query()
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        updateUI()
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
        
//        delegate.arrangeDate = ArrangeDate(by: "app rearange")
//        delegate.arrangeNextBackgroundTask(at: Date())
    }

    // MARK: - UI
    
    @IBOutlet var hasStoodLabel: WKInterfaceLabel!
    @IBOutlet var fireDateLabel: WKInterfaceLabel!
    
    @IBAction func updateButtonClicked() {
        query()
    }
    
    // MARK: - private functions
    private func query() {
        let now = Date()
        //        delegate.fireDates.append(now)
        fireDate = now
        StandHourQuery.shared().complicationShouldReQuery = false
        delegate.procedureStart(at: now) {[unowned self] in // run first time after reboot
            self.updateUI()
        }
    }
    
    private func updateUI() {
        func labelOfHasStood() -> String {
            if hasStood == nil { return NSLocalizedString("Watch Locked", comment: "Watch Locked") }
            if hasStood! {
                return NSLocalizedString("Already stood", comment: "Already stood")
            }
            else {
                return NSLocalizedString("Not stood yet", comment: "Not stood yet.")
            }
        }
        fireDateLabel.setText(DateFormatter.localizedString(from: fireDate, dateStyle: .none, timeStyle: .medium))
        hasStoodLabel.setText(labelOfHasStood())
        //        delegate.queryStandup(at: Date(), shouldArrangeBackgroundTask: false)
    }
//    
//    private func dateString(_ date:Date) -> String {
//        return DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .medium)
//    }
//    
//    @IBAction func arrangeDatesButtonClicked() {
//        tableController.setNumberOfRows(delegate.arrangeDates.count, withRowType: "rowType")
//        for index in 0 ..< delegate.arrangeDates.count {
//            let row = tableController.rowController(at: index) as! RowType
//            let arrangeDate = delegate.arrangeDates[index]
//            let by:String
//            switch arrangeDate.by {
//            case .backgroundTask:
//                by = "background task"
//            case .complicationDirectly:
//                by = "complication"
//            case .deviceLocked:
//                by = "device locked"
//            case .dockAfterSystemRebooting:
//                by = "system reboot"
//            case .firstStart: // no value
//                by = "should not happen"
//            case .remoteNotification:
//                by = "remote notification"
//            case .viewController:
//                by = "extension UI"
//            }
//            row.label.setText("\(by)\n\(dateString(arrangeDate.date))")
//        }
//    }
//    
//    @IBAction func firedatesButtonClicked() {
//        tableController.setNumberOfRows(delegate.fireDates.count, withRowType: "rowType")
//        for index in 0 ..< delegate.fireDates.count {
//            let row = tableController.rowController(at: index) as! RowType
//            let firedate = delegate.fireDates[index]
//            row.label.setText(dateString(firedate))
//        }
//    }
//    
//    @IBOutlet var tableController: WKInterfaceTable!
}

//class RowType: NSObject {
//    @IBOutlet weak var label:WKInterfaceLabel!
//}
