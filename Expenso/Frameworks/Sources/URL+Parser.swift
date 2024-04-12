//
//  URL+Parser.swift
//  datasenses-sdk
//
//  Created by Duc Nguyen on 31/3/24.
//

import Foundation
extension URL {
    var getQueries: Properties {
        var result : Properties = [:]
        
        var dict: [String:String] = [:]
        dict["scheme"] = self.scheme

        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: true) else {
            print("Invalid URL")
            return dict
        }

        if let action = components.host {
            dict["url_action"] = action
        }
        
        let items = components.queryItems ?? []
        items.forEach { dict.updateValue($0.value ?? "", forKey: $0.name) }
        items.filter({ item in
            return item.name.hasPrefix("utm_")
        }).forEach({ item in
            result[item.name] = item.value ?? ""
        })
        result["raw_payload"] = dict
        
        return result
    }
}
