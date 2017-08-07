//
//  DebugViewController.swift
//  Stand Minus
//
//  Created by 肇鑫 on 2017-8-7.
//  Copyright © 2017年 ParusSoft.com. All rights reserved.
//

import UIKit

class DebugViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let defaults = UserDefaults.standard
        
        if let remoteNotificationTimeInterval = defaults.object(forKey: DefaultsKey.remoteNofiticationTimeInterval.key) as? TimeInterval {
            let remoteNotificationArrivingDate = Date(timeIntervalSinceReferenceDate: remoteNotificationTimeInterval)
            remoteNotificationArrivingDateLabel.text = DateFormatter.localizedString(from: remoteNotificationArrivingDate, dateStyle: .none, timeStyle: .short)
        }
        else {
            remoteNotificationArrivingDateLabel.text = "尚无通知到达"
        }
        
        if let hasNotifiedWatchSide = defaults.object(forKey: DefaultsKey.hasNotifedWatchSide.key) as? Bool {
            hasNotifiedWatchSideLabel.text = hasNotifiedWatchSide ? "已通知" : "未通知"
        }
        else {
            hasNotifiedWatchSideLabel.text = "状态未知"
        }
        
        if  let session = (UIApplication.shared.delegate as? AppDelegate)?.session,
            let total = session.receivedApplicationContext["total"] as? Int,
            let hasStoodInCurrentHour = session.receivedApplicationContext["hasStoodInCurrentHour"] as? Bool,
            let date = session.receivedApplicationContext["date"] as? Date {
            
            totalLabel.text = String(total)
            hasStoodInCurrentHourLabel.text = hasStoodInCurrentHour ? "已站立" : "未站立"
            queryDateLabel.text = DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short)
            remainCountsLabel.text = String(session.remainingComplicationUserInfoTransfers)
        }
        else {
            totalLabel.text = "未知"
            hasStoodInCurrentHourLabel.text = "未知"
            queryDateLabel.text = "未知"
            remainCountsLabel.text = "未知"
        }
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func returnButtonClicked(_ sender: Any) {
        dismiss(animated: true)
    }
    
    @IBOutlet weak var remoteNotificationArrivingDateLabel: UILabel!
    @IBOutlet weak var hasNotifiedWatchSideLabel: UILabel!
    @IBOutlet weak var totalLabel: UILabel!
    @IBOutlet weak var hasStoodInCurrentHourLabel: UILabel!
    @IBOutlet weak var queryDateLabel: UILabel!
    @IBOutlet weak var remainCountsLabel: UILabel!
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
