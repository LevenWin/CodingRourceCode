//
//  SessionDataTask.swift
//  KingFisher
//
//  Created by leven on 2020/2/26.
//  Copyright © 2020 leven. All rights reserved.
//

import Foundation

public class SessionDataTask {
    public typealias CancelToken = Int
    struct TaskCallback {
        let onCompleted: Delegate<Result<ImageLoadingResult, KingfisherError>, Void>?
        let options: KingfisherParsedOptionsInfo
    }
    public private(set) var mutableData: Data
    
    public let task: URLSessionDataTask
    
    private var callbackStore = [CancelToken: TaskCallback]()
  
    private var currentToken = 0
    private let lock = NSLock()
    
    let onTaskDone = Delegate<(Result<(Data, URLResponse?), KingfisherError>, [TaskCallback]), Void>()
    
    let onCallbackCancelled = Delegate<(CancelToken, TaskCallback), Void>()
    
    var callbacks: [SessionDataTask.TaskCallback] {
        lock.lock()
        defer { lock.unlock() }
        return Array(callbackStore.values)
    }
    
    var started = false
    
    var containsCallBack: Bool {
        return !callbacks.isEmpty
    }
    
    init(task: URLSessionDataTask) {
        self.task = task
        mutableData = Data()
    }
    
    func addCallback(_ callback: TaskCallback) -> CancelToken {
        lock.lock()
        defer { lock.unlock() }
        callbackStore[currentToken] = callback
        defer { currentToken += 1 }
        return currentToken
    }
    
    func removeCallback(_ token: CancelToken) -> TaskCallback? {
        lock.lock()
        defer { lock.unlock() }
        if let callback = callbackStore[token] {
            callbackStore[token] = nil
            return callback
        }
        return nil
    }
    
    func resume() {
        guard !started else { return }
        started = true
        task.resume()
    }
    
    func cacel(token: CancelToken) {
        guard let callback = removeCallback(token) else { return }
        if callbackStore.count == 0 {
            task.cancel()
        }
        
        onCallbackCancelled.call((token, callback))
    }
    
    func forceCancel() {
        for token in callbackStore.keys {
            cacel(token: token)
        }
    }
    
    func didReceivedData(_ data: Data) {
        mutableData.append(data)
    }
    
    
}
