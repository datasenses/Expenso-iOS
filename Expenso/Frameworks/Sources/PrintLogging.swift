//
//  PrintLogging.swift
//  DSLogger
//
//  Created by Duc Nguyen on 12/3/24.
//  Copyright © 2024 Datasenses. All rights reserved.
//

import Foundation

/// Simply formats and prints the object by calling `print`
class PrintLogging: Logging {
    func addMessage(message: LogMessage) {
        print("[Datasenses - \(message.file) - func \(message.function)] (\(message.level.rawValue)) - \(message.text)")
    }
}

/// Simply formats and prints the object by calling `debugPrint`, this makes things a bit easier if you
/// need to print data that may be quoted for instance.
class PrintDebugLogging: Logging {
    func addMessage(message: LogMessage) {
        debugPrint("[Datasenses - \(message.file) - func \(message.function)] (\(message.level.rawValue)) - \(message.text)")
    }
}
