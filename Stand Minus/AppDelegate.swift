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
    lazy var xgPush = XGPush.defaultManager()
    
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
        
        xgPush.isEnableDebug = true
        
        // remove badge
        let configuration = XGNotificationConfigure(notificationWithCategories: nil, types: [])
        xgPush.notificationConfigure = configuration
        
        xgPush.startXG(withAppID: 2200249931, appKey: "I2V4HX465IMJ", delegate: self)
        
        // report info
        xgPush.reportXGNotificationInfo(launchOptions ?? [:])
        
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

// MARK: - Apple push
extension AppDelegate {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenManager = XGPushTokenManager.default()
        let account = "Zhao Xin"
        // FIXME: Workaround: unbind first or may not register successfully
        tokenManager.unbind(withIdentifer: account, type: .account)
        tokenManager.bind(withIdentifier: account, type: .account)
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        
        guard let rawValue = userInfo["type"] as? String,
            let messageType = MessageType(rawValue:rawValue) else {
            fatalError()
        }
        
        let defaults = UserDefaults.standard
        let now = Date()
        defaults.set(now.timeIntervalSinceReferenceDate, forKey: DefaultsKey.remoteNofiticationTimeInterval.key)
        
        switch messageType {
        case .newHour, .rightNow:
            if session.activationState == .activated && session.isPaired && session.isComplicationEnabled {
                let userInfo:[String:Any] = ["rawValue":rawValue]
                sendDataToAppleWatch(userInfo: userInfo, defaults: defaults, completionHandler: completionHandler)
            }
            else {
                sendNoDataToAppleWatch(defaults: defaults, completionHandler: completionHandler)
            }
        case .fiftyMinutes:
            if session.activationState == .activated && session.isPaired {
                let userInfo:[String:Any] = ["rawValue":rawValue]
                sendDataToAppleWatch(userInfo: userInfo, defaults: defaults, completionHandler: completionHandler)
            }
            else {
                sendNoDataToAppleWatch(defaults: defaults, completionHandler: completionHandler)
            }
        }
    }
    
    private func sendDataToAppleWatch(userInfo:[String:Any], defaults:UserDefaults, completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        session.transferCurrentComplicationUserInfo(userInfo)
        
        defaults.set(true, forKey: DefaultsKey.hasNotifedWatchSide.key)
        completionHandler(.newData)
    }
    
    private func sendNoDataToAppleWatch(defaults:UserDefaults, completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        defaults.set(false, forKey: DefaultsKey.hasNotifedWatchSide.key)
        completionHandler(.noData)
    }
}

// MARK: - Xinge Push Delegate v3.0
// 信鸽的这套API完全是画蛇添足，增加无用的信息。
extension AppDelegate:XGPushDelegate {
    // 应用在后台时的推送
    func xgPush(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse?, withCompletionHandler completionHandler: @escaping () -> Void) {
        
    }
    
    // 应用在前台时也能推送
    func xgPush(_ center: UNUserNotificationCenter, willPresent notification: UNNotification?, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
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
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        UIApplication.shared.registerForRemoteNotifications()
    }
}
