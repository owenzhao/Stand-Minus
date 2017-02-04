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
    
    let session = WCSession.default()
    var handler:(() -> ())? = nil
    
    var xingeToken:String? = nil
    
    let wholeHourNotificationString = UUID().uuidString
    let notifyUserString = UUID().uuidString

    let dateFormatter = { () -> DateFormatter in
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        
        return df
    }()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        // MARK: - register user notification
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { (success, error) in
            guard error == nil else { fatalError(error!.localizedDescription) }
            if success { }
        }
        
        // MARK: - register remote user notification
        application.registerForRemoteNotifications()
        
        let xgs = XGSetting.getInstance() as! XGSetting
        xgs.enableDebug(true)
        
        XGPush.startApp(2200249931, appKey: "I2V4HX465IMJ")
        
        // session
        if WCSession.isSupported() {
            if session.isPaired && session.isWatchAppInstalled {
                session.delegate = self
                session.activate()
            }
        }
        
        return true
    }
    
    // If the device token changes while your app is running, the app object calls the appropriate delegate method again to notify you of the change.
    public func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        xingeToken = XGPush.registerDevice(deviceToken, successCallback: {
            NSLog("xinge register success")
        }) { 
            NSLog("xinge register error")
        }
        print("xinge device token %@", xingeToken!)
    }
    
    public func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("remote notification register failed. Reason: %@", error.localizedDescription)
    }
    
    /*! This delegate method offers an opportunity for applications with the "remote-notification" background mode to fetch appropriate new data in response to an incoming remote notification. You should call the fetchCompletionHandler as soon as you're finished performing that operation, so the system can accurately estimate its power and data cost.
     
     This method will be invoked even if the application was launched or resumed because of the remote notification. The respective delegate methods will be invoked first. Note that this behavior is in contrast to application:didReceiveRemoteNotification:, which is not called in those cases, and which will not be invoked if this method is implemented. !*/
    public func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Swift.Void) {
        if let key = userInfo.keys.first as? String, let date = userInfo.values.first as? Date {
            let reason:String
            if key == wholeHourNotificationString {
                reason = "whole hour notification"
            }
            else {
                reason = "notify user"
            }
            
            let now = Date()
            if now.timeIntervalSince(date) < 10 * 60 {
                
                handler = {
                    if self.session.remainingComplicationUserInfoTransfers > 0 {
                        self.session.sendMessage([reason:date], replyHandler: nil, errorHandler: nil)
                    }
                }
                
                if session.activationState == .activated {
                    handler?()
                }
            }
        }
        
        completionHandler(.newData)
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
                    NSLog("user cancel the request authorization window")
                }
            }
        }
    }
    
    // MARK: - xinge
    // MARK: - XinGe restful api
    func prepareRestfulURLForXingePush(_ reason:String, at notifyDate:Date) -> URL {
        let basePath = "http://openapi.xg.qq.com/v2/push/single_device?"
        let params = { () -> String in
            func md5(_ s:String) -> String {
                let messageData = s.data(using: .utf8)!
                var digestData = Data(count: Int(CC_MD5_DIGEST_LENGTH))
                
                _ = digestData.withUnsafeMutableBytes {digestBytes in
                    messageData.withUnsafeBytes {messageBytes in
                        CC_MD5(messageBytes, CC_LONG(messageData.count), digestBytes)
                    }
                }
                
                return digestData.map { String(format: "%02hhx", $0) }.joined()
            }
            
            let access_id = "access_id=2200249931"
            let timestamp = "timestamp=\(Date().timeIntervalSince1970)" // date sent to xinge
            let device_token = "device_token=\(xingeToken!)"
            let message = { () -> String in
                let d:[String: Any] = ["aps": ["content-available" : 1], "reason": reason]
                let json = try! JSONSerialization.data(withJSONObject: d, options: .init(rawValue: 0))
                let message = String(data: json, encoding: .utf8)!
                
                return "message=\(message)"
            }()
            let message_type = "message_type=0" // for iOS, 0
            let expire_time = "expire_time=\(10 * 60)"
            let send_time = "send_time=\(dateFormatter.string(from: notifyDate))"
            let environment = "environment=2" // 1, release push; 2, debug push
            
            let sign = { () -> String in
                let method = "GET"
                let urlString = "openapi.xg.qq.com/v2/push/single_device"
                let orderedKeyValueString = method + urlString + access_id + device_token + environment + expire_time + message + message_type + send_time + timestamp
                let seceret_key = "aba947471ec1ddaac475729a4eb08793"
                let sign = md5(orderedKeyValueString + seceret_key)
                
                return "sign=\(sign)"
            }()
            
            let params = [access_id, timestamp, device_token, message, message_type, expire_time, send_time, environment, sign].joined(separator: "&")
            
            return params.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
        }()
        
        return URL(string: basePath + params)!
    }
}

extension AppDelegate: WCSessionDelegate {
    /** Called when the session has completed activation. If session state is WCSessionActivationStateNotActivated there will be an error with more details. */
    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        guard error == nil else { fatalError(error!.localizedDescription) }
        if session.activationState == .activated {
            handler?()
            handler = nil
        }
    }
    
    
    /** ------------------------- iOS App State For Watch ------------------------ */
    
    /** Called when the session can no longer be used to modify or add any new transfers and, all interactive messages will be cancelled, but delegate callbacks for background transfers can still occur. This will happen when the selected watch is being changed. */
    public func sessionDidBecomeInactive(_ session: WCSession) {
        
    }
    
    
    /** Called when all delegate callbacks for the previously selected watch has occurred. The session can be re-activated for the now selected watch using activateSession. */
    public func sessionDidDeactivate(_ session: WCSession) {
        
    }
    
    
    /** Called when any of the Watch state properties change. */
    public func sessionWatchStateDidChange(_ session: WCSession) {
        
    }
    
    /** Called on the delegate of the receiver. Will be called on startup if the incoming message caused the receiver to launch. */
    public func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        if let key = message.keys.first, let date = message.values.first as? Date {
            let reason:String
            if key == "whole hour notification" {
                reason = wholeHourNotificationString
            }
            else {
                reason = notifyUserString
            }
            
            let url = prepareRestfulURLForXingePush(reason, at: date)
            
            let urlSession = URLSession.shared.dataTask(with: url) { (data, response, error) in
                if error == nil {
                    if let data = data {
                        if let dic = (try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions(rawValue: 0))) as? [String: Any],
                            let returnCode = dic["ret_code"] as? Int {
                            if returnCode == 0 { NSLog("push to Xinge succeeds.") }
                            else { print("push failed, error code: %@", returnCode) }
                        }
                        else {
                            print("url session error, reason: %@", error!.localizedDescription)
                        }
                    }
                }
            }
            
            urlSession.resume()
            
        }
    }
    
    
    //    /** Called on the delegate of the receiver when the sender sends a message that expects a reply. Will be called on startup if the incoming message caused the receiver to launch. */
    //    public func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Swift.Void) {
    //        
    //    }
}
