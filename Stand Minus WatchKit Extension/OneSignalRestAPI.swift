//
//  OneSignalRestAPI.swift
//  Push Server
//
//  Created by 肇鑫 on 2018-10-15.
//  Copyright © 2018 ParusSoft.com. All rights reserved.
//

import Foundation
/*
    curl --include \
        --request POST \
        --header "Content-Type: application/json; charset=utf-8" \
        --header "Authorization: Basic YOUR_REST_API_KEY" \
        --data-binary "{\"app_id\": \"YOUR_APP_ID\",
        \"contents\": {\"en\": \"English Message\"},
        \"filters\": [{\"field\": "\tag\", \"key\": \"level\", \"relation\": \">\", \"value\": \"10\"},{\"operator\": \"OR\"},{\"field\": \"amount_spent\", \"relation\": \">\",\"value\": \"0\"}]}" \
        https://onesignal.com/api/v1/notifications
*/

/*
    {
        "app_id": "5eb5a37e-b458-11e3-ac11-000c2940e62c",
        "filters": [
            {"field": "tag", "key": "level", "relation": "=", "value": "10"},
            {"operator": "OR"}, {"field": "amount_spent", "relation": ">", "value": "0"}
        ],
        "data": {"foo": "bar"},
        "contents": {"en": "English Message"}
    }
*/

/*
 curl --include \
      --request POST \
      --header "Content-Type: application/json" \
      --data-binary "{\"app_id\" : \"xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx\",
 \"identifier\":\"ce777617da7f548fe7a9ab6febb56cf39fba6d382000c0395666288d961ee566\",
 \"language\":\"en\",
 \"timezone\":-28800,
 \"game_version\":\"1.0\",
 \"device_os\":\"7.0.4\",
 \"device_type\":0,
 \"device_model\":\"iPhone 8,2\",
 \"tags\":{\"a\":\"1\",\"foo\":\"bar\"}}" \
      https://onesignal.com/api/v1/players
 */

/*
 {"success": true, "id": "ffffb794-ba37-11e3-8077-031d62f86ebf" }
 */
class OneSignalRestAPI {
    static let registerDevice = Notification.Name("registerDevice")
    let url = URL(string: "https://onesignal.com/api/v1/players")!
    private let deviceID:String
    lazy var request:URLRequest = calculateURLRequest()
    
    init(deviceID:String) {
        self.deviceID = deviceID
    }
        
    private func calculateURLRequest() -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // data
        // TODO: - add ids here
        let message = Message(identifier: deviceID, username: "Zhao Xin")
        let encoder = JSONEncoder()
        let json = try! encoder.encode(message)
        request.httpBody = json
        
        // header
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        return request
    }
    
    struct Message:Encodable {
        let appId = "bb94f238-18db-434f-90b9-527a068664aa"
        let identifier:String
//        let testType = 1
        let language = "zh-Hans"
        let timezone = TimeZone.current.secondsFromGMT()
        let gameVersion = "5.0.1"
        let deviceOs = "8.0"
        let deviceType = 0 // for iOS, since there was no wathcOS now.
        let deviceModel = "iPhone 8,2"
        let tags:[String:String]
        
        init(identifier:String, username:String) {
            self.identifier = identifier
            self.tags = ["user_name" : username]
        }
        
        enum CodingKeys: String, CodingKey {
            case appId = "app_id"
            case identifier
//            case testType = "test_type"
            case language
            case timezone
            case gameVersion = "game_version"
            case deviceOs = "device_os"
            case deviceType = "device_type"
            case deviceModel = "device_model"
            case tags
        }
    }
}

// MARK: - return code
struct Response:Decodable {
    let success:Bool
    let id:String
}
