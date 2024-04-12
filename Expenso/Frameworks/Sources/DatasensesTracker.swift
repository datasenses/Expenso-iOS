//
//  Track.swift
//  Datasenses
//
//  Created by Duc Nguyen on 12/3/24.
//  Copyright © 2024 Datasenses. All rights reserved.
//

import Foundation

func += <K, V> (left: inout [K: V], right: [K: V]) {
    for (k, v) in right {
        left.updateValue(v, forKey: k)
    }
}

final class DatasensesTracker {
    let apiKey: String
    let lock: ReadWriteLock
    let datasensesStorage: DatasensesStorage
    weak var datasensesInstance: DatasensesInstance?
    
    init(apiKey: String, lock: ReadWriteLock, datasensesStorage: DatasensesStorage) {
        self.apiKey = apiKey
        self.lock = lock
        self.datasensesStorage = datasensesStorage
    }
    
    func track(event: String,
               properties: Properties? = nil,
               timedEvents: InternalProperties,
               datasensesIdentity: DatasensesIdentity,
               epochInterval: Double) -> InternalProperties {
        
        if !(datasensesInstance?.trackAutomaticEventsEnabled ?? false) && event.hasPrefix("ae_") {
            return timedEvents
        }
        assertPropertyTypes(properties)
        
        let epochMilliseconds = round(epochInterval * 1000)
        let eventStartTime = timedEvents[event] as? Double
        var p = InternalProperties()
        SystemProperties.systemPropertiesLock.read {
            p += SystemProperties.defaults
        }
        p[EventKey.unixTimestamp] = "\(epochMilliseconds)"
        var shadowTimedEvents = timedEvents
        if eventStartTime != nil {
            shadowTimedEvents.removeValue(forKey: event)
        }
        
        if datasensesIdentity.anonymousId != nil {
            p[EventKey.clientId] = datasensesIdentity.anonymousId
        }
        if datasensesIdentity.userId != nil {
            p[EventKey.customerId] = datasensesIdentity.userId
        }
        if let appInstanceId = datasensesInstance?.appInstallationID {
            p[EventKey.installationID] = appInstanceId
        }
        
        if let properties = properties {
            p[EventKey.properties] = properties
        }
        p[EventKey.name] = event
        
        let trackEvent: InternalProperties = p
        
        self.datasensesStorage.saveEntity(trackEvent, type: .events)
        DatasensesStorage.saveTimedEvents(timedEvents: shadowTimedEvents)
        return shadowTimedEvents
    }
    
    
    func time(event: String?, timedEvents: InternalProperties, startTime: Double) -> InternalProperties {
        if datasensesInstance?.hasOptedOutTracking() ?? false {
            return timedEvents
        }
        var updatedTimedEvents = timedEvents
        guard let event = event, !event.isEmpty else {
            Logger.error(message: "datasenses cannot time an empty event")
            return updatedTimedEvents
        }
        updatedTimedEvents[event] = startTime
        return updatedTimedEvents
    }
    
    func clearTimedEvents(_ timedEvents: InternalProperties) -> InternalProperties {
        var updatedTimedEvents = timedEvents
        updatedTimedEvents.removeAll()
        return updatedTimedEvents
    }
    
    func clearTimedEvent(event: String?, timedEvents: InternalProperties) -> InternalProperties {
        var updatedTimedEvents = timedEvents
        guard let event = event, !event.isEmpty else {
            Logger.error(message: "datasenses cannot clear an empty timed event")
            return updatedTimedEvents
        }
        updatedTimedEvents.removeValue(forKey: event)
        return updatedTimedEvents
    }
}
