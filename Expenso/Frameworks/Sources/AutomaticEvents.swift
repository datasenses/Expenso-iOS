//
//  AutomaticEvents.swift
//  Datasenses
//
//  Created by Duc Nguyen on 12/3/24.
//  Copyright © 2024 Datasenses. All rights reserved.
//



import Foundation
import UIKit
//import StoreKit

protocol AEDelegate: AnyObject {
    func track(event: String, properties: Properties?)
}

final class AutomaticEvents: NSObject/*, SKPaymentTransactionObserver, SKProductsRequestDelegate*/ {
    
    var _minimumSessionDuration: UInt64 = 10000
    var minimumSessionDuration: UInt64 {
        get {
            return _minimumSessionDuration
        }
        set {
            _minimumSessionDuration = newValue
        }
    }
    var _maximumSessionDuration: UInt64 = UINT64_MAX
    var maximumSessionDuration: UInt64 {
        get {
            return _maximumSessionDuration
        }
        set {
            _maximumSessionDuration = newValue
        }
    }
    
    //    var awaitingTransactions = [String: SKPaymentTransaction]()
    let defaults = UserDefaults(suiteName: DatasensesUserDefaultsKeys.suiteName)
    weak var delegate: AEDelegate?
    var sessionLength: TimeInterval = 0
    var sessionStartTime: TimeInterval = Date().timeIntervalSince1970
    var hasAddedObserver = false
    
    //    let awaitingTransactionsWriteLock = DispatchQueue(label: "io.datasenses.awaiting_transactions_writeLock", qos: .userInitiated, autoreleaseFrequency: .workItem)
    
    func initializeEvents() {
        let firstOpenKey = InternalKeys.firstOpenKey
        if let defaults = defaults, !defaults.bool(forKey: firstOpenKey) {
            defaults.set(true, forKey: firstOpenKey)
            defaults.synchronize()
            delegate?.track(event: EventName.appInstalled, properties: ["first_app_open_date": Date()])
            
        }
        if let defaults = defaults, let infoDict = Bundle.main.infoDictionary {
            let appVersionKey = InternalKeys.appVersionKey
            let appVersionValue = infoDict["CFBundleShortVersionString"]
            let savedVersionValue = defaults.string(forKey: appVersionKey)
            if let appVersionValue = appVersionValue as? String,
               let savedVersionValue = savedVersionValue,
               appVersionValue.compare(savedVersionValue, options: .numeric, range: nil, locale: nil) == .orderedDescending {
                delegate?.track(event: EventName.appUpdated, properties: ["app_version": appVersionValue, "previous_app_version": savedVersionValue])
                defaults.set(appVersionValue, forKey: appVersionKey)
                defaults.synchronize()
            } else if savedVersionValue == nil {
                defaults.set(appVersionValue, forKey: appVersionKey)
                defaults.synchronize()
            }
        }
        
        /*
         NotificationCenter.default.addObserver(self,
         selector: #selector(appWillResignActive(_:)),
         name: UIApplication.willResignActiveNotification,
         object: nil)
         
         NotificationCenter.default.addObserver(self,
         selector: #selector(appDidBecomeActive(_:)),
         name: UIApplication.didBecomeActiveNotification,
         object: nil)
         
         SKPaymentQueue.default().add(self)
         */
    }
    
    /*
     @objc func appWillResignActive(_ notification: Notification) {
     sessionLength = roundOneDigit(num: Date().timeIntervalSince1970 - sessionStartTime)
     if sessionLength >= Double(minimumSessionDuration / 1000) &&
     sessionLength <= Double(maximumSessionDuration / 1000) {
     delegate?.track(event: "ae_session", properties: ["ae_session_length": sessionLength])
     }
     }
     
     @objc func appDidBecomeActive(_ notification: Notification) {
     sessionStartTime = Date().timeIntervalSince1970
     }
     
     
     func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
     var productsRequest = SKProductsRequest()
     var productIdentifiers: Set<String> = []
     awaitingTransactionsWriteLock.async { [self] in
     for transaction: AnyObject in transactions {
     if let trans = transaction as? SKPaymentTransaction {
     switch trans.transactionState {
     case .purchased:
     productIdentifiers.insert(trans.payment.productIdentifier)
     awaitingTransactions[trans.payment.productIdentifier] = trans
     case .failed: break
     case .restored: break
     default: break
     }
     }
     }
     if !productIdentifiers.isEmpty {
     productsRequest = SKProductsRequest(productIdentifiers: productIdentifiers)
     productsRequest.delegate = self
     productsRequest.start()
     }
     }
     
     
     }
     
     
     func roundOneDigit(num: TimeInterval) -> TimeInterval {
     return round(num * 10.0) / 10.0
     }
     
     func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
     awaitingTransactionsWriteLock.async { [self] in
     for product in response.products {
     if let trans = awaitingTransactions[product.productIdentifier] {
     delegate?.track(event: "ae_iap", properties: ["ae_iap_price": "\(product.price)",
     "ae_iap_quantity": trans.payment.quantity,
     "ae_iap_name": product.productIdentifier])
     awaitingTransactions.removeValue(forKey: product.productIdentifier)
     }
     }
     }
     }
     */
}

