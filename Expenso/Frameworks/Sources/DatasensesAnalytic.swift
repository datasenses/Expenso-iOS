//
//  Datasenses.swift
//  Datasenses
//
//  Created by Duc Nguyen on 12/3/24.
//  Copyright © 2024 Datasenses. All rights reserved.
//

import Foundation
import UIKit


/// The primary class for integrating Datasenses with your app.
open class DatasensesAnalytic {
    
    /**
     Initializes an instance of the API with the given project token.
     
     Returns a new Datasenses instance API object. This allows you to create more than one instance
     of the API object, which is convenient if you'd like to send data to more than
     one Datasenses project from a single app.
     
     - parameter apiKey:                    your project apiKey
     - parameter trackAutomaticEvents:      Whether or not to collect common mobile events
     - parameter flushInterval:             Optional. Interval to run background flushing
     - parameter optOutTrackingByDefault:   Optional. Whether or not to be opted out from tracking by default
     
     - returns: returns a datasenses instance if needed to keep throughout the project.
     You can always get the instance by calling getInstance(name)
     */
    @discardableResult
    open class func initialize(apiKey: String,
                               trackAutomaticEvents: Bool = true,
                               flushInterval: Double = 60,
                               optOutTrackingByDefault: Bool = false) -> DatasensesInstance {
        return DatasensesManager.sharedInstance.initialize(apiKey: apiKey,
                                                           flushInterval: flushInterval,
                                                           trackAutomaticEvents: trackAutomaticEvents,
                                                           optOutTrackingByDefault: optOutTrackingByDefault)
    }
    
    
    /**
     Returns the main instance that was initialized.
     
     If not specified explicitly, the main instance is always the last instance added
     
     - returns: returns the main Datasenses instance
     */
    open class func shared() -> DatasensesInstance {
        if let instance = DatasensesManager.sharedInstance.getMainInstance() {
            return instance
        } else {
#if !targetEnvironment(simulator)
            assert(false, "You have to call initialize(token:trackAutomaticEvents:) before calling the main instance, " +
                   "or define a new main instance if removing the main one")
#endif
            
            return DatasensesAnalytic.initialize(apiKey: "", trackAutomaticEvents: true)
        }
    }
    
}

final class DatasensesManager {
    static let sharedInstance = DatasensesManager()
    private var mainInstance: DatasensesInstance?
    private let readWriteLock: ReadWriteLock
    private let instanceQueue: DispatchQueue
    
    init() {
        Logger.addLogging(PrintLogging())
        readWriteLock = ReadWriteLock(label: "io.datasenses.instance.manager.lock")
        instanceQueue = DispatchQueue(label: "io.datasenses.instance.manager.instance", qos: .utility, autoreleaseFrequency: .workItem)
    }
    
    func initialize(apiKey: String,
                    flushInterval: Double,
                    trackAutomaticEvents: Bool,
                    optOutTrackingByDefault: Bool = false) -> DatasensesInstance {
        instanceQueue.sync {
            let instance = DatasensesInstance(apiKey: apiKey,
                                              flushInterval: flushInterval,
                                              trackAutomaticEvents: trackAutomaticEvents,
                                              optOutTrackingByDefault: optOutTrackingByDefault)
            readWriteLock.write {
                mainInstance = instance
            }
        }
        return mainInstance!
    }
    
    
    func getMainInstance() -> DatasensesInstance? {
        return mainInstance
    }
    
    
}
