//
//  DefaultsKey.swift
//  Stand Minus WatchKit Extension
//
//  Created by 肇鑫 on 2017-7-7.
//  Copyright © 2017年 ParusSoft.com. All rights reserved.
//

import Foundation

enum DefaultsKey:String {
    case lastQueryTimeInterval = "last query time interval"
    case hasStoodInCurrentHour = "has Stood in current hour"
    case remoteNofiticationTimeInterval = "remote notification time intervals"
    case hasNotifedWatchSide = "has notifed watch side"
    case messageType = "message type"
    
    var key:String {
        return self.rawValue
    }
}
