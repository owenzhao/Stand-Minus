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
import OneSignal

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    private(set) var session:WCSession!
    private var messageTypeRawValue:String? = nil
    lazy private var calendar = Calendar(identifier: .gregorian)
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
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
        
        if WCSession.isSupported() {
            session = WCSession.default
            session.delegate = self
            session.activate()
        }
        
        // register OneSignal
        let notificationReceivedBlock: OSHandleNotificationReceivedBlock = { [unowned self] notification in
            self.messageTypeRawValue = notification?.payload.additionalData["type"] as? String
        }
        let onesignalInitSettings = [kOSSettingsKeyAutoPrompt: false]
        
        // Replace 'YOUR_APP_ID' with your OneSignal App ID.
        OneSignal.initWithLaunchOptions(launchOptions,
                                        appId: "bb94f238-18db-434f-90b9-527a068664aa",
                                        handleNotificationReceived: notificationReceivedBlock,
                                        handleNotificationAction: nil,
                                        settings: onesignalInitSettings)

        OneSignal.inFocusDisplayType = OSNotificationDisplayType.notification;
        
        // Recommend moving the below line to prompt for push after informing the user about
        //   how your app will use them.
        OneSignal.promptForPushNotifications(userResponse: { accepted in
            print("User accepted notifications: \(accepted)")
            
            // add tag
            OneSignal.sendTag("user_name", value: "Zhao Xin")
        })
        
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
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        
        func predictMessageType() -> MessageType {
            let now = Date()
            let cps = calendar.dateComponents([.hour, .minute], from: now)
            
            switch cps.hour! {
            case 0..<12:
                if cps.minute! < 50 {
                    return .newHour
                }
                
                return .ignoreMe
            default:
                switch cps.minute! {
                case 0..<50:
                    return .newHour
                case 50...58:
                    return .fiftyMinutes
                default:
                    return .ignoreMe
                }
            }
        }
        
        // remove previous untransferred current complication userinfo if there was.
        session.outstandingUserInfoTransfers.forEach { transfer in
            if transfer.isCurrentComplicationInfo && transfer.isTransferring {
                transfer.cancel()
            }
        }
        
        let defaults = UserDefaults.standard
        
        guard self.messageTypeRawValue == MessageType.pushServerNotify.rawValue else { // ignore bad type
            sendNoDataToAppleWatch(defaults: defaults, completionHandler: completionHandler)
            
            return
        }
        
        let messageType = predictMessageType()
        
        defer {
            self.messageTypeRawValue = nil
        }
        
        let now = Date()
        defaults.set(now.timeIntervalSinceReferenceDate, forKey: DefaultsKey.remoteNofiticationTimeInterval.key)
        
        switch messageType {
        case .newHour:
            if session.activationState == .activated && session.isPaired && session.isComplicationEnabled {
                let userInfo:[String:Any] = ["rawValue":messageType.rawValue]
                sendDataToAppleWatch(userInfo: userInfo, defaults: defaults, completionHandler: completionHandler)
            }
            else {
                sendNoDataToAppleWatch(defaults: defaults, completionHandler: completionHandler)
            }
        case .fiftyMinutes:
            if session.activationState == .activated && session.isPaired {
                let userInfo:[String:Any] = ["rawValue":messageType.rawValue]
                sendDataToAppleWatch(userInfo: userInfo, defaults: defaults, completionHandler: completionHandler)
            }
            else {
                sendNoDataToAppleWatch(defaults: defaults, completionHandler: completionHandler)
            }
        case .ignoreMe:
            sendNoDataToAppleWatch(defaults: defaults, completionHandler: completionHandler)
        default:
            fatalError("should never happens.")
        }
    }
    
    private func sendDataToAppleWatch(userInfo:[String:Any], defaults:UserDefaults, completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        
        session.transferCurrentComplicationUserInfo(userInfo)
        
        defaults.set(true, forKey: DefaultsKey.hasNotifiedWatchSide.key)
        completionHandler(.newData)
    }
    
    private func sendNoDataToAppleWatch(defaults:UserDefaults, completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        
        defaults.set(false, forKey: DefaultsKey.hasNotifiedWatchSide.key)
        completionHandler(.noData)
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
