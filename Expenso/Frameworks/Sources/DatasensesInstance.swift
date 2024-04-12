//
//  DatasensesInstance.swift
//  Datasenses
//
//  Created by Duc Nguyen on 12/3/24.
//  Copyright © 2024 Datasenses. All rights reserved.
//

import Foundation
import UIKit
import SystemConfiguration
import CoreTelephony

/**
 *  Delegate protocol for controlling the Datasenses API's network behavior.
 */
public protocol DatasensesDelegate: AnyObject {
    /**
     Asks the delegate if data should be uploaded to the server.
     
     - parameter datasenses: The datasenses instance
     
     - returns: return true to upload now or false to defer until later
     */
    func datasensesWillFlush(_ datasenses: DatasensesInstance) -> Bool
}

public typealias Properties = [String: DatasensesType]

typealias InternalProperties = [String: Any]
typealias Queue = [InternalProperties]


protocol AppLifecycle {
    func applicationDidBecomeActive()
    func applicationWillResignActive()
}

/// The class that represents the Datasenses Instance
open class DatasensesInstance: CustomDebugStringConvertible, FlushDelegate, AEDelegate {
    
    /// apiKey string that identifies the project to track data to
    open var apiKey = ""
    
    /// The a DatasensesDelegate object that gives control over Datasenses network activity.
    open weak var delegate: DatasensesDelegate?
    
    /// distinctId string that uniquely identifies the current user.
    open var distinctId = ""
    
    /// anonymousId string that uniquely identifies the device.
    open var anonymousId: String?
    
    /// userId string that identify is called with.
    open var userId: String?
    
    /// alias string that uniquely identifies the current user.
    open var alias: String?
    
    let datasensesStorage: DatasensesStorage
    
    let firebaseHelper: FirebaseHelper
    
    /// appInstallationID string that uniquely identifies the device.
    open var appInstallationID: String?
    
    /// This allows enabling or disabling collecting common mobile events,
    open var trackAutomaticEventsEnabled: Bool
    
    /// Flush timer's interval.
    /// Setting a flush interval of 0 will turn off the flush timer and you need to call the flush() API manually
    /// to upload queued data to the Datasenses server.
    open var flushInterval: Double {
        get {
            return flusher.flushInterval
        }
        set {
            flusher.flushInterval = newValue
        }
    }
    
    /// Control whether the library should flush data to Datasenses when the app
    /// enters the background. Defaults to true.
    open var flushOnBackground: Bool {
        get {
            return flusher.flushOnBackground
        }
        set {
            flusher.flushOnBackground = newValue
        }
    }
    
    
    /// The `flushBatchSize` property determines the number of events sent in a single network request to the Datasenses server.
    /// By configuring this value, you can optimize network usage and manage the frequency of communication between the client
    /// and the server. The maximum size is 50; any value over 50 will default to 50.
    open var flushBatchSize: Int {
        get {
            return flusher.flushBatchSize
        }
        set {
            flusher.flushBatchSize = min(newValue, APIConstants.maxBatchSize)
        }
    }
    
    
    open var debugDescription: String {
        return "Datasenses(\n"
        + "    Token: \(apiKey),\n"
        + "    Distinct Id: \(distinctId)\n"
        + ")"
    }
    
    /// This allows enabling or disabling of all Datasenses logs at run time.
    /// - Note: All logging is disabled by default. Usually, this is only required
    ///         if you are running in to issues with the SDK and you need support.
    open var loggingEnabled: Bool = false {
        didSet {
            if loggingEnabled {
                Logger.enableLevel(.debug)
                Logger.enableLevel(.info)
                Logger.enableLevel(.warning)
                Logger.enableLevel(.error)
                Logger.info(message: "Logging Enabled")
            } else {
                Logger.info(message: "Logging Disabled")
                Logger.disableLevel(.debug)
                Logger.disableLevel(.info)
                Logger.disableLevel(.warning)
                Logger.disableLevel(.error)
            }
        }
    }
    
    
    /// The minimum session duration (ms) that is tracked in automatic events.
    /// The default value is 10000 (10 seconds).
#if os(iOS) || os(tvOS) || os(visionOS)
    open var minimumSessionDuration: UInt64 {
        get {
            return automaticEvents.minimumSessionDuration
        }
        set {
            automaticEvents.minimumSessionDuration = newValue
        }
    }
    
    /// The maximum session duration (ms) that is tracked in automatic events.
    /// The default value is UINT64_MAX (no maximum session duration).
    open var maximumSessionDuration: UInt64 {
        get {
            return automaticEvents.maximumSessionDuration
        }
        set {
            automaticEvents.maximumSessionDuration = newValue
        }
    }
#endif
    var trackingQueue: DispatchQueue
    var networkQueue: DispatchQueue
    var optOutStatus: Bool?
    
    var timedEvents = InternalProperties()
    
    let readWriteLock: ReadWriteLock
#if os(iOS) && !targetEnvironment(macCatalyst)
    var connectionStatus = getConnectionStatus()
    static let telephonyInfo = CTTelephonyNetworkInfo()
#endif
    
    var taskId = UIBackgroundTaskIdentifier.invalid
    
    let flusher: DataFlusher
    let tracker: DatasensesTracker
    
    let automaticEvents = AutomaticEvents()
    
    init(apiKey: String, flushInterval: Double, trackAutomaticEvents: Bool, optOutTrackingByDefault: Bool = false) {
        self.apiKey = apiKey
        
        trackAutomaticEventsEnabled = trackAutomaticEvents

        let label = "io.datasenses.\(self.apiKey)"
        trackingQueue = DispatchQueue(label: "\(label).tracking)", qos: .utility, autoreleaseFrequency: .workItem)
        networkQueue = DispatchQueue(label: "\(label).network)", qos: .utility, autoreleaseFrequency: .workItem)
        
        datasensesStorage = DatasensesStorage(instanceName: apiKey)
        
        firebaseHelper = FirebaseHelper()
        
        readWriteLock = ReadWriteLock(label: "io.datasenses.globallock")
        flusher = DataFlusher(apiKey: apiKey)
        tracker = DatasensesTracker(apiKey: self.apiKey,
                                    lock: self.readWriteLock,
                                    datasensesStorage: datasensesStorage)
        tracker.datasensesInstance = self

        flusher.delegate = self
        distinctId = defaultDeviceId()
        
        flusher.flushInterval = flushInterval
        setupListeners()
        unarchive()
        getInstallationID()
        // check whether we should opt out by default
        // note: we don't override opt out persistence here since opt-out default state is often
        // used as an initial state while GDPR information is being collected
        if optOutTrackingByDefault && (hasOptedOutTracking() || optOutStatus == nil) {
            optOutTracking()
        }
        
        if !DatasensesInstance.isiOSAppExtension() && trackAutomaticEvents {
            automaticEvents.delegate = self
            automaticEvents.initializeEvents()
        }
        
    }
    
    
    private func setupListeners() {
        let notificationCenter = NotificationCenter.default
#if os(iOS) && !targetEnvironment(macCatalyst)
        readNetworkType()
        // Temporarily remove the ability to monitor the radio change due to a crash issue might relate to the api from Apple
        // https://openradar.appspot.com/46873673
        //    notificationCenter.addObserver(self,
        //                                   selector: #selector(setCurrentRadio),
        //                                   name: .CTRadioAccessTechnologyDidChange,
        //                                   object: nil)
#endif // os(iOS)
        if !DatasensesInstance.isiOSAppExtension() {
            notificationCenter.addObserver(self,
                                           selector: #selector(applicationWillResignActive(_:)),
                                           name: UIApplication.willResignActiveNotification,
                                           object: nil)
            notificationCenter.addObserver(self,
                                           selector: #selector(applicationDidBecomeActive(_:)),
                                           name: UIApplication.didBecomeActiveNotification,
                                           object: nil)
            notificationCenter.addObserver(self,
                                           selector: #selector(applicationDidEnterBackground(_:)),
                                           name: UIApplication.didEnterBackgroundNotification,
                                           object: nil)
            notificationCenter.addObserver(self,
                                           selector: #selector(applicationWillEnterForeground(_:)),
                                           name: UIApplication.willEnterForegroundNotification,
                                           object: nil)
        }
    }
    
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    static func isiOSAppExtension() -> Bool {
        return Bundle.main.bundlePath.hasSuffix(".appex")
    }
    
    
    static func sharedUIApplication() -> UIApplication? {
        guard let sharedApplication =
                UIApplication.perform(NSSelectorFromString("sharedApplication"))?.takeUnretainedValue() as? UIApplication else {
            return nil
        }
        return sharedApplication
    }
    
    
    @objc private func applicationDidBecomeActive(_ notification: Notification) {
        flusher.applicationDidBecomeActive()
    }
    
    @objc private func applicationWillResignActive(_ notification: Notification) {
        flusher.applicationWillResignActive()
    }
    
    
    @objc private func applicationDidEnterBackground(_ notification: Notification) {
        guard let sharedApplication = DatasensesInstance.sharedUIApplication() else {
            return
        }
        
        if hasOptedOutTracking() {
            return
        }
        
        let completionHandler: () -> Void = { [weak self] in
            guard let self = self else { return }
            
            if self.taskId != UIBackgroundTaskIdentifier.invalid {
                sharedApplication.endBackgroundTask(self.taskId)
                self.taskId = UIBackgroundTaskIdentifier.invalid
            }
        }
        
        taskId = sharedApplication.beginBackgroundTask(expirationHandler: completionHandler)
        
        if flushOnBackground {
            flush(performFullFlush: true, completion: completionHandler)
        }
    }
    
    @objc private func applicationWillEnterForeground(_ notification: Notification) {
        guard let sharedApplication = DatasensesInstance.sharedUIApplication() else {
            return
        }
        
        if taskId != UIBackgroundTaskIdentifier.invalid {
            sharedApplication.endBackgroundTask(taskId)
            taskId = UIBackgroundTaskIdentifier.invalid
        }
        
    }
    
    
    func defaultDeviceId() -> String {
        return uniqueIdentifierForDevice() ?? UUID().uuidString // use a random UUID by default
    }
    
    func uniqueIdentifierForDevice() -> String? {
        var distinctId: String?
        if NSClassFromString("UIDevice") != nil {
            distinctId = UIDevice.current.identifierForVendor?.uuidString
        } else {
            distinctId = nil
        }
        
        return distinctId
    }
    
    
#if os(iOS) && !targetEnvironment(macCatalyst)
    @objc func readNetworkType() {
        SystemProperties.defaults[EventKey.networkType] = connectionStatus.rawValue
        
        var networkRadio = ""
        
        let prefix = "CTRadioAccessTechnology"
        if #available(iOS 12.0, *) {
            if let radioDict = DatasensesInstance.telephonyInfo.serviceCurrentRadioAccessTechnology {
                for (_, value) in radioDict where !value.isEmpty && value.hasPrefix(prefix) {
                    // the first should be the prefix, second the target
                    let components = value.components(separatedBy: prefix)
                    
                    // Something went wrong and we have more than prefix:target
                    guard components.count == 2 else {
                        continue
                    }
                    
                    // Safe to directly access by index since we confirmed count == 2 above
                    let radioValue = components[1]
                    
                    // Send to parent
                    networkRadio += networkRadio.isEmpty ? radioValue : ", \(radioValue)"
                }
                
                networkRadio = networkRadio.isEmpty ? "None": networkRadio
            }
        } else {
            networkRadio = DatasensesInstance.telephonyInfo.currentRadioAccessTechnology ?? "None"
            if networkRadio.hasPrefix(prefix) {
                networkRadio = (networkRadio as NSString).substring(from: prefix.count)
            }
        }
        
        trackingQueue.async {
            SystemProperties.systemPropertiesLock.write { [weak self, networkRadio] in
                SystemProperties.defaults[EventKey.networkRadio] = networkRadio
                
                guard self != nil else {
                    return
                }
                
                SystemProperties.defaults[EventKey.networkCarrier] = ""
                if #available(iOS 12.0, *) {
                    if let carrierName = DatasensesInstance.telephonyInfo.serviceSubscriberCellularProviders?.first?.value.carrierName {
                        SystemProperties.defaults[EventKey.networkCarrier] = carrierName
                    }
                } else {
                    if let carrierName = DatasensesInstance.telephonyInfo.subscriberCellularProvider?.carrierName {
                        SystemProperties.defaults[EventKey.networkCarrier] = carrierName
                    }
                }
            }
        }
    }
#endif // os(iOS)
}

extension DatasensesInstance {
    // MARK: - Identity
    
    /**
     Sets the distinct ID of the current user.
     
     Datasenses uses a randomly generated persistent UUID  as the default local distinct ID.
     
     
     For tracking events, you do not need to call `identify:`. However,
     **Datasenses User profiles always requires an explicit call to `identify:`.**
     If calls are made to
     `set:`, `increment` or other `People`
     methods prior to calling `identify:`, then they are queued up and
     flushed once `identify:` is called.
     
     If you'd like to use the default distinct ID for Datasenses People as well
     (recommended), call `identify:` using the current distinct ID:
     
     - parameter usePeople: boolean that controls whether or not to set the people distinctId to the event distinctId.
     This should only be set to false if you wish to prevent people profile updates for that user.
     - parameter completion: an optional completion handler for when the identify has completed.
     */
    public func identify(distinctId: String, usePeople: Bool = true, completion: (() -> Void)? = nil) {
        if hasOptedOutTracking() {
            if let completion = completion {
                DispatchQueue.main.async(execute: completion)
            }
            return
        }
        if distinctId.isEmpty {
            Logger.error(message: "\(self) cannot identify blank distinct id")
            if let completion = completion {
                DispatchQueue.main.async(execute: completion)
            }
            return
        }
#if DEBUG
        UserDefaults.standard.set(true, forKey: InternalKeys.dsDebugIdentifiedKey)
#endif
        trackingQueue.async { [weak self, distinctId, usePeople] in
            guard let self = self else { return }
            
            // If there's no anonymousId assigned yet, that means distinctId is stored in the storage. Assigning already stored
            // distinctId as anonymousId on identify and also setting a flag to notify that it might be previously logged in user
            if self.anonymousId == nil {
                self.anonymousId = self.distinctId
            }
            
            if self.userId == nil {
                self.readWriteLock.write {
                    self.userId = distinctId
                }
            }
            
            if distinctId != self.distinctId {
                let oldDistinctId = self.distinctId
                self.readWriteLock.write {
                    self.alias = nil
                    self.distinctId = distinctId
                    self.userId = distinctId
                }
                self.track(event: "identify", properties: ["anon_distinct_id": oldDistinctId])
            }
            
            if usePeople {
                self.datasensesStorage.identifyPeople(token: self.apiKey)
            }
            
            DatasensesStorage.saveIdentity(DatasensesIdentity(
                distinctID: self.distinctId,
                anonymousId: self.anonymousId,
                userId: self.userId,
                alias: self.alias))
            if let completion = completion {
                DispatchQueue.main.async(execute: completion)
            }
        }
        
        if DatasensesInstance.isiOSAppExtension() {
            flush()
        }
    }
    
    /**
     The alias method creates an alias which Datasenses will use to remap one id to another.
     Multiple aliases can point to the same identifier.
     
     Please note: With Datasenses Identity Merge enabled, calling alias is no longer required
     but can be used to merge two IDs in scenarios where identify() would fail
     
     
     `datasensesInstance.createAlias("New ID", distinctId: datasensesInstance.distinctId)`
     
     You can add multiple id aliases to the existing id
     
     `datasensesInstance.createAlias("Newer ID", distinctId: datasensesInstance.distinctId)`
     
     
     - parameter alias:      A unique identifier that you want to use as an identifier for this user.
     - parameter distinctId: The current user identifier.
     - parameter andIdentify: an optional boolean that controls whether or not to call 'identify' with your current
     user identifier(not alias). Default to true for keeping your signup funnels working correctly in most cases.
     - parameter completion: an optional completion handler for when the createAlias has completed.
     This should only be set to false if you wish to prevent people profile updates for that user.
     */
    public func createAlias(_ alias: String, distinctId: String, usePeople: Bool = true, andIdentify: Bool = true, completion: (() -> Void)? = nil) {
        if hasOptedOutTracking() {
            if let completion = completion {
                DispatchQueue.main.async(execute: completion)
            }
            return
        }
        
        if distinctId.isEmpty {
            Logger.error(message: "\(self) cannot identify blank distinct id")
            if let completion = completion {
                DispatchQueue.main.async(execute: completion)
            }
            return
        }
        
        if alias.isEmpty {
            Logger.error(message: "\(self) create alias called with empty alias")
            if let completion = completion {
                DispatchQueue.main.async(execute: completion)
            }
            return
        }
#if DEBUG
        UserDefaults.standard.set(true, forKey: InternalKeys.dsDebugAliasedKey)
#endif
        if alias != distinctId {
            trackingQueue.async { [weak self, alias] in
                guard let self = self else {
                    if let completion = completion {
                        DispatchQueue.main.async(execute: completion)
                    }
                    return
                }
                self.readWriteLock.write {
                    self.alias = alias
                }
                
                var distinctIdSnapshot: String?
                var anonymousIdSnapshot: String?
                var userIdSnapshot: String?
                var aliasSnapshot: String?
                
                self.readWriteLock.read {
                    distinctIdSnapshot = self.distinctId
                    anonymousIdSnapshot = self.anonymousId
                    userIdSnapshot = self.userId
                    aliasSnapshot = self.alias
                }
                
                DatasensesStorage.saveIdentity(DatasensesIdentity(
                    distinctID: distinctIdSnapshot!,
                    anonymousId: anonymousIdSnapshot,
                    userId: userIdSnapshot,
                    alias: aliasSnapshot))
            }
            
            let properties = ["distinct_id": distinctId, "alias": alias]
            track(event: "create_alias", properties: properties)
            if andIdentify {
                identify(distinctId: distinctId, usePeople: usePeople)
            }
            flush(completion: completion)
        } else {
            Logger.error(message: "alias: \(alias) matches distinctId: \(distinctId) - skipping api call.")
            if let completion = completion {
                DispatchQueue.main.async(execute: completion)
            }
        }
    }
    
    /**
     Clears all stored properties including the distinct Id.
     Useful if your app's user logs out.
     
     - parameter completion: an optional completion handler for when the reset has completed.
     */
    public func reset(completion: (() -> Void)? = nil) {
        flush()
        trackingQueue.async { [weak self] in
            guard let self = self else {
                return
            }
            
            DatasensesStorage.deleteDSUserDefaultsData()
            self.readWriteLock.write {
                self.timedEvents = InternalProperties()
                self.anonymousId = self.defaultDeviceId()
                self.distinctId =  self.anonymousId ?? ""
                self.userId = nil
                self.alias = nil
            }
            
            self.datasensesStorage.resetEntities()
            self.archive()
            if let completion = completion {
                DispatchQueue.main.async(execute: completion)
            }
        }
    }
}

extension DatasensesInstance {
    // MARK: - Persistence
    
    public func archive() {
        self.readWriteLock.read {
            DatasensesStorage.saveTimedEvents(timedEvents: timedEvents)
            DatasensesStorage.saveIdentity(DatasensesIdentity(
                distinctID: distinctId,
                anonymousId: anonymousId,
                userId: userId,
                alias: alias))
        }
    }
    
    func unarchive() {
        self.readWriteLock.write {
            optOutStatus = DatasensesStorage.loadOptOutStatusFlag()
            timedEvents = DatasensesStorage.loadTimedEvents()
            let datasensesIdentity = DatasensesStorage.loadIdentity()
            
            (distinctId, anonymousId, userId, alias) = (
                datasensesIdentity.distinctID,
                datasensesIdentity.anonymousId,
                datasensesIdentity.userId,
                datasensesIdentity.alias)
            
            if distinctId.isEmpty {
                anonymousId = defaultDeviceId()
                distinctId = anonymousId ?? ""
                userId = nil
                DatasensesStorage.saveIdentity(DatasensesIdentity(
                    distinctID: distinctId,
                    anonymousId: anonymousId,
                    userId: userId,
                    alias: alias))
            }
        }
    }
    
    func getInstallationID() {
        self.readWriteLock.write {
            firebaseHelper.getInstallationID {[weak self] installationID, error in
                if let error = error {
                    Logger.error(message: "Get Installation ID fail with error: \(error.localizedDescription)")
                }
                if let installationID = installationID {
                    Logger.info(message: "Installation ID: \(installationID)")
                    self?.appInstallationID = installationID
                }
            }
        }
    }
}

extension DatasensesInstance {
    // MARK: - Flush
    
    /**
     Uploads queued data to the Datasenses server.
     
     By default, queued data is flushed to the Datasenses servers every minute (the
     default for `flushInterval`), and on background (since
     `flushOnBackground` is on by default). You only need to call this
     method manually if you want to force a flush at a particular moment.
     
     - parameter performFullFlush: A optional boolean value indicating whether a full flush should be performed. If `true`, a full flush will be triggered, sending all events to the server. Default to `false`, a partial flush will be executed for reducing memory footprint.
     - parameter completion: an optional completion handler for when the flush has completed.
     */
    public func flush(performFullFlush: Bool = false, completion: (() -> Void)? = nil) {
        if hasOptedOutTracking() {
            if let completion = completion {
                DispatchQueue.main.async(execute: completion)
            }
            return
        }
        trackingQueue.async { [weak self, completion] in
            guard let self = self else {
                if let completion = completion {
                    DispatchQueue.main.async(execute: completion)
                }
                return
            }
            
            if let shouldFlush = self.delegate?.datasensesWillFlush(self), !shouldFlush {
                if let completion = completion {
                    DispatchQueue.main.async(execute: completion)
                }
                return
            }
            
            // automatic events will NOT be flushed until one of the flags is non-nil
            let eventQueue = self.datasensesStorage.loadEntitiesInBatch(
                type: self.persistenceTypeFromFlushType(.events),
                batchSize: performFullFlush ? Int.max : self.flushBatchSize,
                excludeAutomaticEvents: !self.trackAutomaticEventsEnabled
            )
            
            
            self.networkQueue.async { [weak self, completion] in
                guard let self = self else {
                    if let completion = completion {
                        DispatchQueue.main.async(execute: completion)
                    }
                    return
                }
                self.flushQueue(eventQueue, type: .events)
                
                if let completion = completion {
                    DispatchQueue.main.async(execute: completion)
                }
            }
        }
    }
    
    private func persistenceTypeFromFlushType(_ type: FlushType) -> PersistenceType {
        switch type {
        case .events:
            return PersistenceType.events
        }
    }
    
    func flushQueue(_ queue: Queue, type: FlushType) {
        if hasOptedOutTracking() {
            return
        }
        self.flusher.flushQueue(queue, type: type)
    }
    
    func flushSuccess(type: FlushType, ids: [Int32]) {
        trackingQueue.async { [weak self] in
            guard let self = self else {
                return
            }
            self.datasensesStorage.removeEntitiesInBatch(type: self.persistenceTypeFromFlushType(type), ids: ids)
        }
    }
    
}

extension DatasensesInstance {
    // MARK: - Track
    
    /**
     Tracks an event with properties.
     Properties are optional and can be added only if needed.
     
     Properties will allow you to segment your events in your Datasenses reports.
     Property keys must be String objects and the supported value types need to conform to DatasensesType.
     DatasensesType can be either String, Int, UInt, Double, Float, Bool, [DatasensesType], [String: DatasensesType], Date, URL, or NSNull.
     If the event is being timed, the timer will stop and be added as a property.
     
     - parameter event:      event name
     - parameter properties: properties dictionary
     */
    public func track(event: String, properties: Properties? = nil) {
        if hasOptedOutTracking() {
            return
        }
        
        let epochInterval = Date().timeIntervalSince1970
        
        trackingQueue.async { [weak self, event, properties, epochInterval] in
            guard let self = self else {
                return
            }
            var shadowTimedEvents = InternalProperties()
            
            self.readWriteLock.read {
                shadowTimedEvents = self.timedEvents
            }
            
            let datasensesIdentity = DatasensesIdentity(distinctID: self.distinctId,
                                                        anonymousId: self.anonymousId,
                                                        userId: self.userId,
                                                        alias: nil)
            let timedEventsSnapshot = self.tracker.track(event: event,
                                                         properties: properties,
                                                         timedEvents: shadowTimedEvents,
                                                         datasensesIdentity: datasensesIdentity,
                                                         epochInterval: epochInterval)
            
            self.readWriteLock.write {
                self.timedEvents = timedEventsSnapshot
            }
        }
        
        if DatasensesInstance.isiOSAppExtension() {
            flush()
        }
    }
    
    
    /**
     Starts a timer that will be stopped and added as a property when a
     corresponding event is tracked.
     
     This method is intended to be used in advance of events that have
     a duration. For example, if a developer were to track an "Image Upload" event
     she might want to also know how long the upload took. Calling this method
     before the upload code would implicitly cause the `track`
     call to record its duration.
     
     - precondition:
     // begin timing the image upload:
     datasensesInstance.time(event:"Image Upload")
     // upload the image:
     self.uploadImageWithSuccessHandler() { _ in
     // track the event
     datasensesInstance.track("Image Upload")
     }
     
     - parameter event: the event name to be timed
     
     */
    public func time(event: String) {
        let startTime = Date().timeIntervalSince1970
        trackingQueue.async { [weak self, startTime, event] in
            guard let self = self else { return }
            let timedEvents = self.tracker.time(event: event, timedEvents: self.timedEvents, startTime: startTime)
            self.readWriteLock.write {
                self.timedEvents = timedEvents
            }
            DatasensesStorage.saveTimedEvents(timedEvents: timedEvents)
        }
    }
    
    /**
     Retrieves the time elapsed for the named event since time(event:) was called.
     
     - parameter event: the name of the event to be tracked that was passed to time(event:)
     */
    public func eventElapsedTime(event: String) -> Double {
        var timedEvents = InternalProperties()
        self.readWriteLock.read {
            timedEvents = self.timedEvents
        }
        
        if let startTime = timedEvents[event] as? TimeInterval {
            return Date().timeIntervalSince1970 - startTime
        }
        return 0
    }
    
    /**
     Clears all current event timers.
     */
    public func clearTimedEvents() {
        trackingQueue.async { [weak self] in
            guard let self = self else { return }
            self.readWriteLock.write {
                self.timedEvents = InternalProperties()
            }
            DatasensesStorage.saveTimedEvents(timedEvents: InternalProperties())
        }
    }
    
    /**
     Clears the event timer for the named event.
     
     - parameter event: the name of the event to clear the timer for
     */
    public func clearTimedEvent(event: String) {
        trackingQueue.async { [weak self, event] in
            guard let self = self else { return }
            
            let updatedTimedEvents = self.tracker.clearTimedEvent(event: event, timedEvents: self.timedEvents)
            DatasensesStorage.saveTimedEvents(timedEvents: updatedTimedEvents)
        }
    }
    
    
    /**
     Opt out tracking.
     
     This method is used to opt out tracking. This causes all events and people request no longer
     to be sent back to the Datasenses server.
     */
    public func optOutTracking() {
        trackingQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.readWriteLock.write { [weak self] in
                guard let self = self else {
                    return
                }
                
                self.alias = nil
                
                self.userId = nil
                self.anonymousId = self.defaultDeviceId()
                self.distinctId = self.anonymousId ?? ""
                DatasensesStorage.saveTimedEvents(timedEvents: InternalProperties())
            }
            self.archive()
            self.readWriteLock.write {
                self.optOutStatus = true
            }
            self.readWriteLock.read {
                DatasensesStorage.saveOptOutStatusFlag(value: self.optOutStatus!)
            }
            
        }
    }
    
    /**
     Opt in tracking.
     
     Use this method to opt in an already opted out user from tracking. People updates and track calls will be
     sent to Datasenses after using this method.
     
     This method will internally track an opt in event to your project.
     
     - parameter distintId: an optional string to use as the distinct ID for events
     - parameter properties: an optional properties dictionary that could be passed to add properties to the opt-in event
     that is sent to Datasenses
     */
    public func optInTracking(distinctId: String? = nil, properties: Properties? = nil) {
        trackingQueue.async { [weak self] in
            guard let self = self else { return }
            self.readWriteLock.write {
                self.optOutStatus = false
            }
            self.readWriteLock.read {
                DatasensesStorage.saveOptOutStatusFlag(value: self.optOutStatus!)
            }
            if let distinctId = distinctId {
                self.identify(distinctId: distinctId)
            }
            self.track(event: "opt_in", properties: properties)
        }
    }
    
    /**
     Returns if the current user has opted out tracking.
     
     - returns: the current super opted out tracking status
     */
    public func hasOptedOutTracking() -> Bool {
        var optOutStatusShadow: Bool?
        readWriteLock.read {
            optOutStatusShadow = optOutStatus
        }
        return optOutStatusShadow ?? false
    }
    
    public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        trackingQueue.async { [weak self] in
            self?.track(event: EventName.appLaunched, properties: launchOptions as? Properties)
        }
        return true
    }
    
    public func handleUrl(url: URL?) {
        guard var utmQueries = url?.getQueries as? Properties else {
            return
        }
        
        trackingQueue.async { [weak self] in
            self?.track(event: EventName.utmVisited, properties: utmQueries)
        }
    }
}
