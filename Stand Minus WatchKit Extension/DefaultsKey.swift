//
//  DefaultsKey.swift
//  Stand Minus WatchKit Extension
//
//  Created by 肇鑫 on 2017-7-7.
//  Copyright © 2017年 ParusSoft.com. All rights reserved.
//

import Foundation

enum DefaultsKey:String {
    case total
    case lastQueryTimeInterval = "last query time interval"
    case hasStoodInCurrentHour = "has Stood in current hour"
    
    case remoteNofiticationTimeInterval = "remote notification time intervals"
    case hasNotifiedWatchSide = "has notified watch side"
    
    var key:String {
        return self.rawValue
    }
}
