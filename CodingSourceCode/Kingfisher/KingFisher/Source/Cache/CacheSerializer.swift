//
//  CacheSerializer.swift
//  KingFisher
//
//  Created by leven on 2020/2/26.
//  Copyright © 2020 leven. All rights reserved.
//

import Foundation

public protocol CacheSerializer {
    
    func data(with image: Image, original: Data?) -> Data?
    
    func image(with data: Data, options: KingfisherParsedOptionsInfo) -> Image?
    
    @available(*, deprecated, message: "Deprecated. Implement the method with same name but with `KingfisherParsedOptionsInfo` instead.")
    func image(with data: Data, options: KingfisherOptionsInfo?) -> Image?
}


extension CacheSerializer {
    public func image(with data: Data, options: KingfisherOptionsInfo?) -> Image? {
        return image(with: data, options: KingfisherParsedOptionsInfo(options))
    }
}

public struct DefaultCacheSerializer: CacheSerializer {
    public static let `default` = DefaultCacheSerializer()
    
    public init() {}
    
    public func data(with image: Image, original: Data?) -> Data? {
        return image.kf.data(format: original?.kf.imageFormat ?? .unknown)
    }
    public func image(with data: Data, options: KingfisherParsedOptionsInfo) -> Image? {
        return KingfisherWrapper.image(data: data, options: options.imageCreatingOptions)
    }
}
