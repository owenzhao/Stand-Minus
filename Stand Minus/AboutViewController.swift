//
//  AboutViewController.swift
//  Stand Minus
//
//  Created by 肇鑫 on 2017-2-14.
//  Copyright © 2017年 ParusSoft.com. All rights reserved.
//

import UIKit

class AboutViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    @IBAction func privacyNoticeButtonClicked(_ sender: Any) {
        let url = URL(string: "http://parussoft.com/en/Stand_Minus/privacy_notice.html")!
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}
