//
//  CallbackQueue.swift
//  KingFisher
//
//  Created by leven on 2020/2/25.
//  Copyright © 2020 leven. All rights reserved.
//

import Foundation

public enum CallbackQueue {
    case mainAsync
    
    case mainCurrentOrAsync
    
    case untouch
    
    case dispatch(DispatchQueue)
    
    public func execute(_ block: @escaping () -> Void) {
        switch self {
        case .mainAsync:
            DispatchQueue.main.sync {
                block()
            }
        case .mainCurrentOrAsync:
            DispatchQueue.main.safeAsync {
                block()
            }
        case .untouch:
            block()
        case .dispatch(let queue):
            queue.async {
                block()
            }
        }
    }
    
    var queue: DispatchQueue {
        switch self {
        case .mainAsync:
            return .main
        case .mainCurrentOrAsync:
            return .main
        case .untouch: return OperationQueue.current?.underlyingQueue ?? .main
        case .dispatch(let queue):
            return queue
        }
    }
}

extension DispatchQueue {
    // This method will dispatch the `block` to self. If `self` is the main queue, and current thread is main thread, the blcok will be invoked immediately instead of being diapatched.
    func safeAsync(_ block: @escaping ()->()) {
        if self == DispatchQueue.main && Thread.isMainThread {
            block()
        } else {
            async {
                block()
            }
        }
    }
}
