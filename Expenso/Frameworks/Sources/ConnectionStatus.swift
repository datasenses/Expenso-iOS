//
//  ConnectionStatus.swift
//  datasenses-sdk
//
//  Created by Duc Nguyen on 19/3/24.
//

import Foundation
import SystemConfiguration


internal enum ConnectionStatus : String{
    case cellular
    case wifi
    case offline
    case unknown
}

extension ConnectionStatus {
    init(reachabilityFlags flags: SCNetworkReachabilityFlags) {
        let connectionRequired = flags.contains(.connectionRequired)
        let isReachable = flags.contains(.reachable)
        let isCellular = flags.contains(.isWWAN)
        if !connectionRequired && isReachable {
            if isCellular {
                self = .cellular
            } else {
                self = .wifi
            }
        } else {
            self =  .offline
        }
    }
}

internal func getConnectionStatus() -> ConnectionStatus {
    var zeroAddress = sockaddr_in()
    zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
    zeroAddress.sin_family = sa_family_t(AF_INET)
    
    guard let defaultRouteReachability = (withUnsafePointer(to: &zeroAddress) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { zeroSockAddress in
            SCNetworkReachabilityCreateWithAddress(nil, zeroSockAddress)
        }
    }) else {
        return .unknown
    }
    
    var flags : SCNetworkReachabilityFlags = []
    if !SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags) {
        return .unknown
    }
    
    return ConnectionStatus(reachabilityFlags: flags)
}
