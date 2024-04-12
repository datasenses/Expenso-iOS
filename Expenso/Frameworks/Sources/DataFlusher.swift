//
//  Flush.swift
//  Datasenses
//
//  Created by Duc Nguyen on 12/3/24.
//  Copyright © 2024 Datasenses. All rights reserved.
//

import Foundation

protocol FlushDelegate: AnyObject {
    func flush(performFullFlush: Bool, completion: (() -> Void)?)
    func flushSuccess(type: FlushType, ids: [Int32])
}

class DataFlusher: AppLifecycle {
    var timer: Timer?
    weak var delegate: FlushDelegate?
    var flushRequest: FlushRequest
    var flushOnBackground = true
    var _flushInterval = 0.0
    var _flushBatchSize = APIConstants.maxBatchSize
    private let flushIntervalReadWriteLock: DispatchQueue
    
    var flushInterval: Double {
        get {
            flushIntervalReadWriteLock.sync {
                return _flushInterval
            }
        }
        set {
            flushIntervalReadWriteLock.sync(flags: .barrier, execute: {
                _flushInterval = newValue
            })
            
            delegate?.flush(performFullFlush: false, completion: nil)
            startFlushTimer()
        }
    }
    
    var flushBatchSize: Int {
        get {
            return _flushBatchSize
        }
        set {
            _flushBatchSize = newValue
        }
    }
    
    required init(apiKey: String) {
        self.flushRequest = FlushRequest(apiKey: apiKey)
        flushIntervalReadWriteLock = DispatchQueue(label: "io.datasenses.flush_interval.lock", qos: .utility, attributes: .concurrent, autoreleaseFrequency: .workItem)
    }
    
    func flushQueue(_ queue: Queue, type: FlushType) {
        if flushRequest.requestNotAllowed() {
            return
        }
        flushQueueInBatches(queue, type: type)
    }
    
    func startFlushTimer() {
        stopFlushTimer()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }
            
            if self.flushInterval > 0 {
                self.timer?.invalidate()
                self.timer = Timer.scheduledTimer(timeInterval: self.flushInterval,
                                                  target: self,
                                                  selector: #selector(self.flushSelector),
                                                  userInfo: nil,
                                                  repeats: true)
            }
        }
    }
    
    @objc func flushSelector() {
        delegate?.flush(performFullFlush: false, completion: nil)
    }
    
    func stopFlushTimer() {
        if let timer = timer {
            DispatchQueue.main.async { [weak self, timer] in
                timer.invalidate()
                self?.timer = nil
            }
        }
    }
    
    func flushQueueInBatches(_ queue: Queue, type: FlushType) {
        var mutableQueue = queue
        while !mutableQueue.isEmpty {
            let batchSize = min(mutableQueue.count, flushBatchSize)
            let range = 0..<batchSize
            let batch = Array(mutableQueue[range])
            let ids: [Int32] = batch.map { entity in
                (entity[InternalKeys.dsEntityId] as? Int32) ?? 0
            }
            
            Logger.debug(message: "Sending batch of data")
            Logger.debug(message: batch as Any)
            let requestData = JSONHandler.encodeAPIData(batch)
            if let requestData = requestData {
                
                let success = flushRequest.sendRequest(requestData,
                                                       type: type)
                
                if success {
                    // remove
                    delegate?.flushSuccess(type: type, ids: ids)
                    mutableQueue = self.removeProcessedBatch(batchSize: batchSize,
                                                             queue: mutableQueue,
                                                             type: type)
                } else {
                    break
                }
            }
        }
    }
    
    func removeProcessedBatch(batchSize: Int, queue: Queue, type: FlushType) -> Queue {
        var shadowQueue = queue
        let range = 0..<batchSize
        if let lastIndex = range.last, shadowQueue.count - 1 > lastIndex {
            shadowQueue.removeSubrange(range)
        } else {
            shadowQueue.removeAll()
        }
        return shadowQueue
    }
    
    // MARK: - Lifecycle
    func applicationDidBecomeActive() {
        startFlushTimer()
    }
    
    func applicationWillResignActive() {
        stopFlushTimer()
    }
    
}
