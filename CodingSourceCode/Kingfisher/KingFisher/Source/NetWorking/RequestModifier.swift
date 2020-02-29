//
//  RequestModifier.swift
//  KingFisher
//
//  Created by leven on 2020/2/26.
//  Copyright © 2020 leven. All rights reserved.
//

import Foundation

public protocol ImageDownloadRequestModifier {
    func modified(for request: URLRequest) -> URLRequest?
}

public struct AnyModifier: ImageDownloadRequestModifier {
    let blcok: (URLRequest) -> URLRequest?
    
    public func modified(for request: URLRequest) -> URLRequest? {
        return blcok(request)
    }
    public init(modify: @escaping (URLRequest) -> URLRequest?) {
        blcok = modify
    }
}
