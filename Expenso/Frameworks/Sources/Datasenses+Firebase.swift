//
//  Datasenses+Firebase.swift
//  datasenses-sdk
//
//  Created by Duc Nguyen on 21/3/24.
//

import Foundation

import FirebaseInstallations
import FirebaseAnalytics
import FirebaseCore

final class FirebaseHelper {
    
    init() {
        configApp()
    }
    
    private func configApp() {
        FirebaseApp.configure()
    }
    
    func getInstallationID(completion: @escaping (String?, (any Error)?) -> Void) {
        Installations.installations().installationID(completion: completion)
    }
}
