//
//  AppDelegate.swift
//  Stand Minus
//
//  Created by 肇鑫 on 2017-1-31.
//  Copyright © 2017年 ParusSoft.com. All rights reserved.
//

import UIKit
import HealthKit
import UserNotifications
import WatchConnectivity

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    private(set) var session:WCSession!

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        // FIXME: workaround for watchOS 4.0 beta 4 issue
        // "Transaction block failed without an error."
        let sampleType = HKObjectType.categoryType(forIdentifier: .appleStandHour)!
        
        HKHealthStore().requestAuthorization(toShare: nil, read: [sampleType]) { (success, error) in
            if error == nil && success {
            }
            else {
                print(error!.localizedDescription, "\n")
            }
        }
        
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { (success, error) in
            if error == nil && success {
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            }
        }
        
        let setting = XGSetting.getInstance() as! XGSetting
        setting.enableDebug(true)
        
        XGPush.startApp(2200249931, appKey: "I2V4HX465IMJ")
        
        if WCSession.isSupported() {
            session = WCSession.default
            session.delegate = self
            session.activate()
        }
        
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    func applicationShouldRequestHealthAuthorization(_ application: UIApplication) {
        let store = HKHealthStore()
        store.handleAuthorizationForExtension { (success, error) in
            if error == nil {
                if !success {
                    // NSLog("user cancel the request authorization window")
                }
            }
        }
    }
    
}

// MARK: - Xinge push
extension AppDelegate {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print(deviceToken.debugDescription)
        
        let token = XGPush.registerDevice(deviceToken, account: "Zhao Xin", successCallback: {
            NSLog("register to XG success.")
        }) {
            NSLog("register ot XG failed.")
        }
        
        NSLog("XG device token is %@", token!)
        UserDefaults.standard.set(token, forKey: "token")
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        
        print(userInfo)
        print()
        
//        if let rawValue = userInfo["type"] as? String,
//            let type = MessageType(rawValue: rawValue) {
            let defaults = UserDefaults.standard
            let now = Date()
            defaults.set(now.timeIntervalSinceReferenceDate, forKey: DefaultsKey.remoteNofiticationTimeInterval.key)
            
//            switch type {
//            case .newHour, .rightNow:
            if session.activationState == .activated && session.isPaired && session.isComplicationEnabled {
//                let info:[String:Any] = ["type":type.rawValue, "hasComplication":true]
                let info:[String:Any] = ["hasComplication":true]
                session.transferCurrentComplicationUserInfo(info)
                
                defaults.set(true, forKey: DefaultsKey.hasNotifedWatchSide.key)
                completionHandler(.newData)
            }
            else {
                defaults.set(false, forKey: DefaultsKey.hasNotifedWatchSide.key)
                completionHandler(.noData)
            }
//            case .fiftyMinutes:
//                let info = session.receivedApplicationContext
//
//                if let total = info["total"] as? Int,
//                    let hasStoodInCurrentHour = info["hasStoodInCurrentHour"] as? Bool,
//                    let date = info["date"] as? Date {
//                    let now = Date()
//
//                    let calendar = Calendar(identifier: .gregorian)
//                    let hour = calendar.component(.hour, from: date)
//                    let nowHour = calendar.component(.hour, from: now)
//
//                    if now.timeIntervalSince(date) < 60 * 60
//                        && hour == nowHour
//                        && (total < 12 || hasStoodInCurrentHour) {
//
//                        defaults.set(false, forKey: DefaultsKey.hasNotifedWatchSide.key)
//                        completionHandler(.noData)
//                        return
//                    }
//                }
//
//                if session.activationState == .activated && session.isPaired {
//                    let info = ["type":type.rawValue]
//                    session.transferCurrentComplicationUserInfo(info)
//
//                    defaults.set(true, forKey: DefaultsKey.hasNotifedWatchSide.key)
//                    completionHandler(.newData)
//                }
//                else {
//                    defaults.set(false, forKey: DefaultsKey.hasNotifedWatchSide.key)
//                    completionHandler(.noData)
//                }
//            }
//        }
//        else {
//            print("should not happen")
//        }
    }
}

// MARK: - WCSessionDelegate
extension AppDelegate:WCSessionDelegate {
    /** Called when the session has completed activation. If session state is WCSessionActivationStateNotActivated there will be an error with more details. */
    @available(iOS 9.3, *)
    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        
    }
    
    
    /** ------------------------- iOS App State For Watch ------------------------ */
    
    /** Called when the session can no longer be used to modify or add any new transfers and, all interactive messages will be cancelled, but delegate callbacks for background transfers can still occur. This will happen when the selected watch is being changed. */
    @available(iOS 9.3, *)
    public func sessionDidBecomeInactive(_ session: WCSession) {
        
    }
    
    
    /** Called when all delegate callbacks for the previously selected watch has occurred. The session can be re-activated for the now selected watch using activateSession. */
    @available(iOS 9.3, *)
    public func sessionDidDeactivate(_ session: WCSession) {
        
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        
    }
}
