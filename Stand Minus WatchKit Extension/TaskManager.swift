//
//  TaskManager.swift
//  Stand Minus
//
//  Created by 肇鑫 on 2017-1-31.
//  Copyright © 2017年 ParusSoft.com. All rights reserved.
//

import Foundation
import WatchKit

//class TaskManager {
//    class func excute(for reason:Reason, at now:Date) {
//        let data = ComplicationdData.shared()
//        let cal = Calendar(identifier: .gregorian)
//        var cps = cal.dateComponents([.year, .month, .day, .hour], from: now)
//        let minute = cal.component(.minute, from: now)
//        
//        func shouldNotifyUser() -> Bool {
//            return data.total >= 12
//        }
//        
//        func hasStood() -> Bool {
//            return data.hasStood
//        }
//        
//        func isMinuteUnder50() -> Bool {
//            return cps.minute! < 50
//        }
//        
//        func theNextWholeHour() {
//            cps.hour! += 1
//        }
//        
//        var newReason = Reason.theWholeHour
//        
//        defer {
////            // for testing
////            let minute = cal.component(.minute, from: now)
////            cps.minute = minute + 5
////            // testing end
//            let fireDate = cal.date(from: cps)!
//            NSLog("schedule background task at \(DateFormatter.localizedString(from: fireDate, dateStyle: .long, timeStyle:.long))")
//            NSLog()
//            WKExtension.shared().scheduleBackgroundRefresh(withPreferredDate: fireDate, userInfo: newReason.userInfo, scheduledCompletion: { (error) in
//                if error != nil { print(error!.localizedDescription) }
//            })
//        }
//        
//        if reason == .checkStoodFirst {
//            cps.minute! += 1
//            newReason = reason
//        }
//        else {
//            if shouldNotifyUser() {
//                if hasStood() {
//                    theNextWholeHour()
//                }
//                else {
//                    if isMinuteUnder50() {
//                        cps.minute = 50
//                        newReason = .notifyUser
//                    }
//                    else {
//                        theNextWholeHour()
//                    }
//                }
//            }
//            else {
//                theNextWholeHour()
//            }
//        }
//    }
//    
//    enum Reason:Int {
//        case notifyUser = 0
//        case checkStoodFirst
//        case theWholeHour
//        
//        var userInfo:NSSecureCoding {
//            
//            return ["rawValue":self.rawValue] as NSSecureCoding
//        }
//    }
//}
