//
//  ViewController.swift
//  Stand Minus
//
//  Created by 肇鑫 on 2017-1-31.
//  Copyright © 2017年 ParusSoft.com. All rights reserved.
//

import UIKit
import WatchConnectivity

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
//        if WCSession.isSupported() {
//            let session = WCSession.default()
//            let delegate = Session.shared()
//            session.delegate = delegate
//            delegate.textView = logTextView
//            session.activate()
//        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - UI
    private func sendMessage(_ text:String) {
        let session = WCSession.default()
        if session.isReachable {
            session.sendMessage([text:minutesTextField.text!], replyHandler: nil, errorHandler: nil)
            let now = Date()
            let dString = DateFormatter.localizedString(from: now, dateStyle: .none, timeStyle: .medium)
            logTextView.text = logTextView.text + "Shedule \(text) at \(dString)\n"
        }
        else {
            logTextView.text = logTextView.text + "session not reachable \n"
        }
    }
    
    @IBAction func schedulAppRefreshBackgroundTaskButtonClicked(_ sender: UISwitch) {
        if sender.isOn {
            sendMessage("app refresh task")
        }
        
    }
    @IBAction func schedulSnapshotTaskButtonClicked(_ sender: UISwitch) {
        if sender.isOn {
            sendMessage("snapshot task")
        }
    }
    
    @IBOutlet weak var minutesTextField: UITextField!
    @IBOutlet weak var logTextView: UITextView!
    @IBAction func pushButtonClicked(_ sender: Any) {
        let reason = UUID().uuidString
        let url = prepareRestfulURLForXingePush(reason)
        
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
    @IBAction func nslogButtonClicked(_ sender: Any) {
        NSLog("This ia a log")
    }
    // MARK: - XinGe restful api
    func prepareRestfulURLForXingePush(_ reason:String) -> URL {
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
            let device_token = "device_token=5f4ec76de618b33b9e13c85e09439edfbe054c3adb232d1786d67f6a0fc04340"
            let message = { () -> String in
                let d:[String: Any] = ["aps": ["content-available" : 1], "reason": reason]
                let json = try! JSONSerialization.data(withJSONObject: d, options: .init(rawValue: 0))
                let message = String(data: json, encoding: .utf8)!
                
                return "message=\(message)"
            }()
            let message_type = "message_type=0" // for iOS, 0
            let environment = "environment=2" // 1, release push; 2, debug push
            
            let sign = { () -> String in
                let method = "GET"
                let urlString = "openapi.xg.qq.com/v2/push/single_device"
                let orderedKeyValueString = method + urlString + access_id + device_token + environment + message + message_type + timestamp
                let seceret_key = "aba947471ec1ddaac475729a4eb08793"
                let sign = md5(orderedKeyValueString + seceret_key)
                
                return "sign=\(sign)"
            }()
            
            let params = [access_id, timestamp, device_token, message, message_type, environment, sign].joined(separator: "&")
            
            return params.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
        }()
        
        return URL(string: basePath + params)!
    }
}

//class Session: NSObject, WCSessionDelegate{
//    private static var instance:Session? = nil
//    private override init() {}
//    var textView:UITextView? = nil
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
//    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
//        guard error == nil else { fatalError(error!.localizedDescription) }
//        if session.activationState == .activated {
//            DispatchQueue.main.async {
//                self.textView!.text =  "session is activce\n"
//            }
//        }
//    }
//    
//    
//    /** ------------------------- iOS App State For Watch ------------------------ */
//    
//    /** Called when the session can no longer be used to modify or add any new transfers and, all interactive messages will be cancelled, but delegate callbacks for background transfers can still occur. This will happen when the selected watch is being changed. */
//    public func sessionDidBecomeInactive(_ session: WCSession) {
//
//    }
//    
//    
//    /** Called when all delegate callbacks for the previously selected watch has occurred. The session can be re-activated for the now selected watch using activateSession. */
//    public func sessionDidDeactivate(_ session: WCSession) {
//        
//    }
//    
//    
//    /** Called when any of the Watch state properties change. */
//    public func sessionWatchStateDidChange(_ session: WCSession) {
//        
//    }
//    
//    /** Called on the delegate of the receiver. Will be called on startup if the incoming message caused the receiver to launch. */
//    public func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
////        let now = Date()
////        let dString = DateFormatter.localizedString(from: now, dateStyle: .none, timeStyle: .medium)
//        
//        DispatchQueue.main.async {
//            self.textView!.text = "\(self.textView!.text!)\(message.keys.first!)\n"
//        }
//    }
//    
//    
////    /** Called on the delegate of the receiver when the sender sends a message that expects a reply. Will be called on startup if the incoming message caused the receiver to launch. */
////    public func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Swift.Void) {
////        
////    }
//}

