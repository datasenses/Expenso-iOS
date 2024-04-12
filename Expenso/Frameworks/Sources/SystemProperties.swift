//
//  SystemProperties.swift
//  Datasenses
//
//  Created by Duc Nguyen on 12/3/24.
//  Copyright © 2024 Datasenses. All rights reserved.
//

import Foundation
import UIKit
import AdSupport
import FirebaseAnalytics

final class SystemProperties {
    static let systemPropertiesLock = ReadWriteLock(label: "systemPropertiesLock")
    
    static var defaults: InternalProperties = {
        var params = InternalProperties()
        
        var screenSize: CGSize? = nil
        screenSize = UIScreen.main.bounds.size
        if let screenSize = screenSize {
            params[EventKey.deviceScreenHeight]     = Int(screenSize.height)
            params[EventKey.deviceScreenWidth]      = Int(screenSize.width)
        }
#if targetEnvironment(macCatalyst)
        params[EventKey.platform]                = "macOS"
        params[EventKey.osVersion]        = ProcessInfo.processInfo.operatingSystemVersionString
#else
        if SystemProperties.isiOSAppOnMac() {
            // iOS App Running on Apple Silicon Mac
            params[EventKey.platform]                = "macOS"
            // unfortunately, there is no API that reports the correct macOS version
            // for "Designed for iPad" apps running on macOS, so we omit it here rather than mis-report
        } else {
            params[EventKey.platform]                = UIDevice.current.systemName
            params[EventKey.osVersion]        = UIDevice.current.systemVersion
        }
#endif
        let infoDict = Bundle.main.infoDictionary ?? [:]
        
        params[EventKey.appBuild]     = infoDict["CFBundleVersion"] as? String ?? "Unknown"
        params[EventKey.appVersion]   = infoDict["CFBundleShortVersionString"] as? String ?? "Unknown"
        params[EventKey.bundleId]     = infoDict["CFBundleIdentifier"] as? String ?? "Unknown"
        params[EventKey.appInstanceId] = Analytics.appInstanceID() ?? "Unknown"
        
        params[EventKey.sdkVersion]       = SystemProperties.libVersion()
        params[EventKey.deviceManufactor]      = "Apple"
        params[EventKey.deviceModel]      = SystemProperties.deviceModel()
        let idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString.lowercased()
        params[EventKey.idfa] = idfa
        params[EventKey.timezone] = TimeZone.current.identifier
        params[EventKey.createdAt] = Formatter.iso8601.string(from: Date())
        params[EventKey.time] = Formatter.iso8601.string(from: Date())
        params[EventKey.deviceName] = UIDevice.current.name
        params[EventKey.idfv] = UIDevice.current.identifierForVendor?.uuidString
        return params
    }()
    
    
    class func deviceModel() -> String {
        var modelCode : String = "Unknown"
        if SystemProperties.isiOSAppOnMac() {
            // iOS App Running on Apple Silicon Mac
            var size = 0
            sysctlbyname("hw.model", nil, &size, nil, 0)
            var model = [CChar](repeating: 0,  count: size)
            sysctlbyname("hw.model", &model, &size, nil, 0)
            modelCode = String(cString: model)
        } else {
            var systemInfo = utsname()
            uname(&systemInfo)
            let size = MemoryLayout<CChar>.size
            modelCode = withUnsafePointer(to: &systemInfo.machine) {
                $0.withMemoryRebound(to: CChar.self, capacity: size) {
                    String(cString: UnsafePointer<CChar>($0))
                }
            }
        }
        return modelCode
    }
    
    class func isiOSAppOnMac() -> Bool {
        var isiOSAppOnMac = false
        if #available(iOS 14.0, macOS 11.0, watchOS 7.0, tvOS 14.0, *) {
            isiOSAppOnMac = ProcessInfo.processInfo.isiOSAppOnMac
        }
        return isiOSAppOnMac
    }
    
    class func libVersion() -> String {
        return __version
    }
    
}


extension Formatter {
    static let iso8601: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.autoupdatingCurrent
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        return formatter
    }()
}
