//
//  BudgetManager.swift
//  Stand Minus
//
//  Created by 肇鑫 on 2017-1-31.
//  Copyright © 2017年 ParusSoft.com. All rights reserved.
//

import Foundation
import HealthKit

class BudgetManager {
    private static var instance:BudgetManager? = nil
    private let AppRefreshBackgroundTaskBudget = 4
    
    private init() { }
    
    static func shared() -> BudgetManager {
        if instance == nil { instance = BudgetManager() }
        return instance!
    }
    
//    func currentBudget(at date:Date, handler: (Int) -> Int) -> Int {
//        return handler(date)
//    }
}
