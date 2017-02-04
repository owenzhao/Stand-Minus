//
//  InterfaceController.swift
//  Stand Minus WatchKit Extension
//
//  Created by 肇鑫 on 2017-1-31.
//  Copyright © 2017年 ParusSoft.com. All rights reserved.
//

import WatchKit
import Foundation
import WatchConnectivity
import ClockKit

class InterfaceController: WKInterfaceController {

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
//        
//        let session = WCSession.default()
//        session.delegate = Session.shared()
//        session.activate()
        
        // Configure interface objects here.
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }

    @IBAction func updateComplicationButtonClicked() {
        let server = CLKComplicationServer.sharedInstance()
        if let complications = server.activeComplications {
            print("%l complications.", complications.count)
            complications.forEach { server.reloadTimeline(for: $0) }
        }
    }
}

//class Session:NSObject, WCSessionDelegate {
//    private static var instance:Session? = nil
//    private override init() {}
//    
//    class func shared() -> Session {
//        if instance == nil {
//            instance = Session()
//        }
//        
//        return instance!
//    }
//    
//    /** Called when the session has completed activation. If session state is WCSessionActivationStateNotActivated there will be an error with more details. */
//
//    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
//        guard error == nil else { fatalError(error!.localizedDescription) }
//        if session.activationState == .activated {
//            NSLog("watchOS session is ready.")
//            NSLog()
//        }
//    }
//    
//    
//    /** ------------------------- Interactive Messaging ------------------------- */
//    
//    /** Called when the reachable state of the counterpart app changes. The receiver should check the reachable property on receiving this delegate callback. */
//    public func sessionReachabilityDidChange(_ session: WCSession) {
//        
//    }
//    
//    
//    /** Called on the delegate of the receiver. Will be called on startup if the incoming message caused the receiver to launch. */
//    public func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
//        let now = Date()
//        let dString = DateFormatter.localizedString(from: now, dateStyle: .none, timeStyle: .medium)
//        NSLog("message received at \(dString)")
//        if session.activationState == .activated {
//            session.sendMessage(["message received!":""], replyHandler: nil, errorHandler: nil)
//        }
//            
//        if let key = message.keys.first, key == "app refresh task", let minuteString = message.values.first as? String  {
//            let minute = Int(minuteString)!
//            let cal = Calendar(identifier: .gregorian)
//            var cps = cal.dateComponents([.year, .month, .day, .minute], from: now)
//            cps.minute! += minute
//            let fireDate = cal.date(from: cps)!
//            
//            WKExtension.shared().scheduleBackgroundRefresh(withPreferredDate: fireDate, userInfo: nil, scheduledCompletion: { (error) in
//                
//            })
//        }
//        else if let key = message.keys.first, key == "snapshot task", let minuteString = message.values.first as? String {
//            let minute = Int(minuteString)!
//            let cal = Calendar(identifier: .gregorian)
//            var cps = cal.dateComponents([.year, .month, .day, .minute], from: now)
//            cps.minute! += minute
//            let fireDate = cal.date(from: cps)!
//            
//            WKExtension.shared().scheduleSnapshotRefresh(withPreferredDate: fireDate, userInfo: nil, scheduledCompletion: { (error) in
//                
//            })
//        }
//    }
//}
