//
//  AppDelegate.swift
//  ExpenseDiary
//
//  Created by Duc Nguyen on 2/4/24.
//

import Foundation
import UIKit
import SwiftUI
import Datasenses_iOS
import StoreKit

class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        Datasenses.initialize(apiKey: "N4qTG9jDHM_d9kTGSpo--FujKVtZFpolmv-OJiFzYLKf2DlJSX3lY9mnye6zZdbCQKNolp3Ox7MP5veTvFbAfba8pOABCw")
        Datasenses.shared().loggingEnabled = true
        Datasenses.shared().updatePostbackConversionValue(1)
        return Datasenses.shared().application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
}
