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
    lazy var delegate = WKExtension.shared().delegate as! ExtensionDelegate
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        // Configure interface objects here.
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        
//        delegate.queryStandup(at: Date(), shouldArrangeBackgroundTask: false)
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
        
//        delegate.arrangeDate = ArrangeDate(by: "app rearange")
//        delegate.arrangeNextBackgroundTask(at: Date())
    }

    // MARK: - UI
    
    private func dateString(_ date:Date) -> String {
        return DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .medium)
    }
    
    @IBAction func arrangeDatesButtonClicked() {
        tableController.setNumberOfRows(delegate.arrangeDates.count, withRowType: "rowType")
        for index in 0 ..< delegate.arrangeDates.count {
            let row = tableController.rowController(at: index) as! RowType
            let arrangeDate = delegate.arrangeDates[index]
            row.label.setText("\(arrangeDate.by)\n\(dateString(arrangeDate.date))")
        }
    }
    
    @IBAction func firedatesButtonClicked() {
        tableController.setNumberOfRows(delegate.fireDates.count, withRowType: "rowType")
        for index in 0 ..< delegate.fireDates.count {
            let row = tableController.rowController(at: index) as! RowType
            let firedate = delegate.fireDates[index]
            row.label.setText(dateString(firedate))
        }
    }
    
    @IBOutlet var tableController: WKInterfaceTable!
}

class RowType: NSObject {
    @IBOutlet weak var label:WKInterfaceLabel!
}
