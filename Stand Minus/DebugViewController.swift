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
        
        if let hasNotifiedWatchSide = defaults.object(forKey: DefaultsKey.hasNotifiedWatchSide.key) as? Bool {
            hasNotifiedWatchSideLabel.text = hasNotifiedWatchSide ? "已通知" : "未通知"
        }
        else {
            hasNotifiedWatchSideLabel.text = "状态未知"
        }
        
        if let session = (UIApplication.shared.delegate as? AppDelegate)?.session {
            remainCountsLabel.text = {
                guard session.activationState == .activated else {
                    return "Session状态不是.activated。"
                }
                
                guard session.isWatchAppInstalled else {
                    return String("对应手表应用正在安装中……")
                }
                
                guard session.isComplicationEnabled else {
                    return "错误：手表当前表盘未安装Stand-的小部件。"
                }
                
                return String(session.remainingComplicationUserInfoTransfers)
            }()
        }
        else {
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
