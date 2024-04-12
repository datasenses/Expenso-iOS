//
//  Constants.swift
//  Datasenses
//
//  Created by Duc Nguyen on 12/3/24.
//  Copyright © 2024 Datasenses. All rights reserved.
//

import Foundation
import UIKit

struct QueueConstants {
    static var queueSize = 5000
}

struct APIConstants {
    static let maxBatchSize = 50
    static let flushSize = 1000
    static let minRetryBackoff = 60.0
    static let maxRetryBackoff = 600.0
    static let failuresTillBackoff = 2
}

struct InternalKeys {
    static let appVersionKey = "DSAppVersion"
    static let firstOpenKey = "DSFirstOpen"
    
    static let dsEntityId = "ds_entity_id"
    static let dsDebugTrackedKey = "dsDebugTrackedKey"
    static let dsDebugInitCountKey = "dsDebugInitCountKey"
    static let dsDebugImplementedKey = "dsDebugImplementedKey"
    static let dsDebugIdentifiedKey = "dsDebugIdentifiedKey"
    static let dsDebugAliasedKey = "dsDebugAliasedKey"
    static let dsDebugUsedPeopleKey = "dsDebugUsedPeopleKey"
}

struct EventKey {
    static let appBuild = "app_build"
    static let appVersion = "app_version"
    static let clientId = "client_id"
    static let createdAt = "created_at"
    static let osVersion = "os_version"
    static let idfa = "idfa"
    static let idfv = "idfv"
    static let platform = "platform"
    static let sdkVersion = "sdk_version"
    static let timezone = "timezone"
    static let deviceManufactor = "device_manufactor"
    static let deviceModel = "device_model"
    static let deviceName = "device_name"
    static let deviceScreenHeight = "device_screen_height"
    static let deviceScreenWidth = "device_screen_width"
    static let networkType = "network_type"
    static let networkRadio = "network_radio"
    static let networkCarrier = "network_carrier"
    static let bundleId = "bundle_id"
    static let appInstanceId = "app_instance_id"
    static let locale = "locale"
    static let name = "event_name"
    static let customerId = "customer_id"
    static let time = "event_time"
    static let unixTimestamp = "unix_timestamp"
    static let properties = "event_properties"
    static let installationID = "installation_id"
}

struct EventName {
    static let appLaunched = "app_launched"
    static let appUpdated = "app_updated"
    static let appInstalled = "app_installed"
    static let utmVisited = "utm_visited"
}
