//
//  ExtensionDelegate.swift
//  Stand Minus WatchKit Extension
//
//  Created by 肇鑫 on 2017-1-31.
//  Copyright © 2017年 ParusSoft.com. All rights reserved.
//

import WatchKit
import ClockKit
import UserNotifications

class ExtensionDelegate: NSObject, WKExtensionDelegate {

    func applicationDidFinishLaunching() {
        // Perform any final initialization of your application.
    }

    func applicationDidBecomeActive() {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        standardPrecedure()
    }

    func applicationWillResignActive() {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, etc.
    }
    
    deinit {
        ComplicationQuery.terminated()
        ComplicationData.terminate()
    }
    
    func standardPrecedure() {
        let server = CLKComplicationServer.sharedInstance()
        let now = Date()
        let query = ComplicationQuery.shared()
        
        func queryStandup() {
            query.start(at: now) {
                let hasComplication = _hasComplication()
                if hasComplication {
                    updateComplications()
                }
                self.updateUI()
            }
        }
        
        func _hasComplication() -> Bool {
            if let complications = server.activeComplications, !complications.isEmpty {
                return true
            }
            
            return false
        }
        
        func updateComplications() {
            if shouldUpdateComplications() {
                updateComplicationsNow()
            }
        }
        
        func shouldUpdateComplications() -> Bool {
            return query.shouldUpdateComplication
        }
        
        func updateComplicationsNow() {
            server.activeComplications!.forEach { server.reloadTimeline(for: $0) }
        }
        
        queryStandup()
    }
    
    func updateUI() {
        
    }
}
