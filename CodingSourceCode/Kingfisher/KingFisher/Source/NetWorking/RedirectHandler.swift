//
//  REdirectHandler.swift
//  KingFisher
//
//  Created by leven on 2020/2/26.
//  Copyright © 2020 leven. All rights reserved.
//

import Foundation

public protocol ImageDownloadRedirectHandler {
    
    func handleHTTPRedirection(for task: SessionDataTask, reponse: HTTPURLResponse, newRequest: URLRequest, completionHandler: @escaping (URLRequest?) -> Void)
}
public struct AnyRedirectHandler: ImageDownloadRedirectHandler {
    let block: (SessionDataTask, HTTPURLResponse, URLRequest, (URLRequest?) -> Void) -> Void
    
    public func handleHTTPRedirection(for task: SessionDataTask, reponse: HTTPURLResponse, newRequest: URLRequest, completionHandler: (URLRequest?) -> Void) {
        block(task, reponse, newRequest, completionHandler)
    }
    public init(handle: @escaping (SessionDataTask, HTTPURLResponse, URLRequest, (URLRequest?) -> Void) -> Void) {
        block = handle
    }
}
