//
//  DatasensesPersistence.swift
//  Datasenses
//
//  Created by Duc Nguyen on 12/3/24.
//  Copyright © 2021 Datasenses. All rights reserved.
//

import Foundation

enum PersistenceType: String, CaseIterable {
    case events
    case people
}

struct PersistenceConstant {
    static let unIdentifiedFlag = true
}

struct DatasensesIdentity {
    let distinctID: String
    let anonymousId: String?
    let userId: String?
    let alias: String?
}

struct DatasensesUserDefaultsKeys {
    static let suiteName = "Datasenses"
    static let prefix = "datasenses"
    static let optOutStatus = "OptOutStatus"
    static let timedEvents = "timedEvents"
    static let distinctID = "DSDistinctID"
    static let peopleDistinctID = "DSPeopleDistinctID"
    static let anonymousId = "DSAnonymousId"
    static let userID = "DSUserId"
    static let alias = "DSAlias"
}

final class DatasensesStorage {
    
    let instanceName: String
    let dsdb: DSDB
    
    private static let archivedClasses = [NSArray.self, NSDictionary.self, NSSet.self, NSString.self, NSDate.self, NSURL.self, NSNumber.self, NSNull.self]
    
    init(instanceName: String) {
        self.instanceName = instanceName
        dsdb = DSDB(token: instanceName)
    }
    
    deinit {
        dsdb.close()
    }
    
    func closeDB() {
        dsdb.close()
    }
    
    func saveEntity(_ entity: InternalProperties, type: PersistenceType, flag: Bool = false) {
        if let data = JSONHandler.serializeJSONObject(entity) {
            dsdb.insertRow(type, data: data, flag: flag)
        }
    }
    
    func saveEntities(_ entities: Queue, type: PersistenceType, flag: Bool = false) {
        for entity in entities {
            saveEntity(entity, type: type)
        }
    }
    
    func loadEntitiesInBatch(type: PersistenceType, batchSize: Int = Int.max, flag: Bool = false, excludeAutomaticEvents: Bool = false) -> [InternalProperties] {
        var entities = dsdb.readRows(type, numRows: batchSize, flag: flag)
        if excludeAutomaticEvents && type == .events {
            entities = entities.filter { !($0["event"] as! String).hasPrefix("ae_") }
        }
        if type == PersistenceType.people {
            let distinctId = DatasensesStorage.loadIdentity().distinctID
            return entities.map { entityWithDistinctId($0, distinctId: distinctId) }
        }
        return entities
    }
    
    private func entityWithDistinctId(_ entity: InternalProperties, distinctId: String) -> InternalProperties {
        var result = entity;
        result["distinct_id"] = distinctId
        return result
    }
    
    func removeEntitiesInBatch(type: PersistenceType, ids: [Int32]) {
        dsdb.deleteRows(type, ids: ids)
    }
    
    func identifyPeople(token: String) {
        dsdb.updateRowsFlag(.people, newFlag: !PersistenceConstant.unIdentifiedFlag)
    }
    
    func resetEntities() {
        for pType in PersistenceType.allCases {
            dsdb.deleteRows(pType, isDeleteAll: true)
        }
    }
    
    static func saveOptOutStatusFlag(value: Bool) {
        guard let defaults = UserDefaults(suiteName: DatasensesUserDefaultsKeys.suiteName) else {
            return
        }
        defaults.setValue(value, forKey: "\(DatasensesUserDefaultsKeys.prefix)\(DatasensesUserDefaultsKeys.optOutStatus)")
        defaults.synchronize()
    }
    
    static func loadOptOutStatusFlag() -> Bool? {
        guard let defaults = UserDefaults(suiteName: DatasensesUserDefaultsKeys.suiteName) else {
            return nil
        }
        return defaults.object(forKey: "\(DatasensesUserDefaultsKeys.prefix)\(DatasensesUserDefaultsKeys.optOutStatus)") as? Bool
    }
    
    static func saveTimedEvents(timedEvents: InternalProperties) {
        guard let defaults = UserDefaults(suiteName: DatasensesUserDefaultsKeys.suiteName) else {
            return
        }
        do {
            let timedEventsData = try NSKeyedArchiver.archivedData(withRootObject: timedEvents, requiringSecureCoding: false)
            defaults.set(timedEventsData, forKey: "\(DatasensesUserDefaultsKeys.prefix)\(DatasensesUserDefaultsKeys.timedEvents)")
            defaults.synchronize()
        } catch {
            Logger.warn(message: "Failed to archive timed events")
        }
    }
    
    static func loadTimedEvents() -> InternalProperties {
        guard let defaults = UserDefaults(suiteName: DatasensesUserDefaultsKeys.suiteName) else {
            return InternalProperties()
        }
        guard let timedEventsData  = defaults.data(forKey: "\(DatasensesUserDefaultsKeys.prefix)\(DatasensesUserDefaultsKeys.timedEvents)") else {
            return InternalProperties()
        }
        do {
            return try NSKeyedUnarchiver.unarchivedObject(ofClasses: archivedClasses, from: timedEventsData) as? InternalProperties ?? InternalProperties()
        } catch {
            Logger.warn(message: "Failed to unarchive timed events")
            return InternalProperties()
        }
    }
    
    
    static func saveIdentity(_ datasensesIdentity: DatasensesIdentity) {
        guard let defaults = UserDefaults(suiteName: DatasensesUserDefaultsKeys.suiteName) else {
            return
        }
        let prefix = DatasensesUserDefaultsKeys.prefix
        defaults.set(datasensesIdentity.distinctID, forKey: "\(prefix)\(DatasensesUserDefaultsKeys.distinctID)")
        defaults.set(datasensesIdentity.anonymousId, forKey: "\(prefix)\(DatasensesUserDefaultsKeys.anonymousId)")
        defaults.set(datasensesIdentity.userId, forKey: "\(prefix)\(DatasensesUserDefaultsKeys.userID)")
        defaults.set(datasensesIdentity.alias, forKey: "\(prefix)\(DatasensesUserDefaultsKeys.alias)")
        defaults.synchronize()
    }
    
    static func loadIdentity() -> DatasensesIdentity {
        guard let defaults = UserDefaults(suiteName: DatasensesUserDefaultsKeys.suiteName) else {
            return DatasensesIdentity(distinctID: "",
                                      anonymousId: nil,
                                      userId: nil,
                                      alias: nil)
        }
        let prefix = DatasensesUserDefaultsKeys.prefix
        return DatasensesIdentity(
            distinctID: defaults.string(forKey: "\(prefix)\(DatasensesUserDefaultsKeys.distinctID)") ?? "",
            anonymousId: defaults.string(forKey: "\(prefix)\(DatasensesUserDefaultsKeys.anonymousId)"),
            userId: defaults.string(forKey: "\(prefix)\(DatasensesUserDefaultsKeys.userID)"),
            alias: defaults.string(forKey: "\(prefix)\(DatasensesUserDefaultsKeys.alias)"))
    }
    
    static func deleteDSUserDefaultsData() {
        guard let defaults = UserDefaults(suiteName: DatasensesUserDefaultsKeys.suiteName) else {
            return
        }
        let prefix = DatasensesUserDefaultsKeys.prefix
        defaults.removeObject(forKey: "\(prefix)\(DatasensesUserDefaultsKeys.distinctID)")
        defaults.removeObject(forKey: "\(prefix)\(DatasensesUserDefaultsKeys.peopleDistinctID)")
        defaults.removeObject(forKey: "\(prefix)\(DatasensesUserDefaultsKeys.anonymousId)")
        defaults.removeObject(forKey: "\(prefix)\(DatasensesUserDefaultsKeys.userID)")
        defaults.removeObject(forKey: "\(prefix)\(DatasensesUserDefaultsKeys.alias)")
        defaults.removeObject(forKey: "\(prefix)\(DatasensesUserDefaultsKeys.optOutStatus)")
        defaults.removeObject(forKey: "\(prefix)\(DatasensesUserDefaultsKeys.timedEvents)")
        defaults.synchronize()
    }
    
    private func filePathWithType(_ type: String) -> String? {
        let filename = "datasenses-\(instanceName)-\(type)"
        let manager = FileManager.default
        
#if os(iOS)
        let url = manager.urls(for: .libraryDirectory, in: .userDomainMask).last
#else
        let url = manager.urls(for: .cachesDirectory, in: .userDomainMask).last
#endif // os(iOS)
        guard let urlUnwrapped = url?.appendingPathComponent(filename).path else {
            return nil
        }
        
        return urlUnwrapped
    }
    
    
    private func unarchiveWithFilePath(_ filePath: String) -> Any? {
        if #available(iOS 11.0, macOS 10.13, watchOS 4.0, tvOS 11.0, *) {
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)),
                  let unarchivedData = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: DatasensesStorage.archivedClasses, from: data) else {
                Logger.info(message: "Unable to read file at path: \(filePath)")
                removeArchivedFile(atPath: filePath)
                return nil
            }
            return unarchivedData
        } else {
            guard let unarchivedData = NSKeyedUnarchiver.unarchiveObject(withFile: filePath) else {
                Logger.info(message: "Unable to read file at path: \(filePath)")
                removeArchivedFile(atPath: filePath)
                return nil
            }
            return unarchivedData
        }
    }
    
    private func removeArchivedFile(atPath filePath: String) {
        do {
            try FileManager.default.removeItem(atPath: filePath)
        } catch let err {
            Logger.info(message: "Unable to remove file at path: \(filePath), error: \(err)")
        }
    }
    
    private func unarchiveEvents() -> Queue {
        let data = unarchiveWithType(PersistenceType.events.rawValue)
        return data as? Queue ?? []
    }
    
    private func unarchivePeople() -> Queue {
        let data = unarchiveWithType(PersistenceType.people.rawValue)
        return data as? Queue ?? []
    }
    
    private func unarchiveOptOutStatus() -> Bool? {
        return unarchiveWithType("optOutStatus") as? Bool
    }
    
    private func unarchiveProperties() -> (InternalProperties,
                                           String,
                                           String?,
                                           String?,
                                           String?,
                                           String?,
                                           Queue) {
        let properties = unarchiveWithType("properties") as? InternalProperties
        let timedEvents =
        properties?["timedEvents"] as? InternalProperties ?? InternalProperties()
        let distinctId =
        properties?["distinctId"] as? String ?? ""
        let anonymousId =
        properties?["anonymousId"] as? String ?? nil
        let userId =
        properties?["userId"] as? String ?? nil
        let alias =
        properties?["alias"] as? String ?? nil
        let peopleDistinctId =
        properties?["peopleDistinctId"] as? String ?? nil
        let peopleUnidentifiedQueue =
        properties?["peopleUnidentifiedQueue"] as? Queue ?? Queue()
        
        return (timedEvents,
                distinctId,
                anonymousId,
                userId,
                alias,
                peopleDistinctId,
                peopleUnidentifiedQueue)
    }
    
    private func unarchiveWithType(_ type: String) -> Any? {
        let filePath = filePathWithType(type)
        guard let path = filePath else {
            Logger.info(message: "bad file path, cant fetch file")
            return nil
        }
        
        guard let unarchivedData = unarchiveWithFilePath(path) else {
            Logger.info(message: "can't unarchive file")
            return nil
        }
        
        return unarchivedData
    }
    
    
    
}
