//
//  ImageProcessor.swift
//  KingFisher
//
//  Created by leven on 2020/2/26.
//  Copyright © 2020 leven. All rights reserved.
//

import Foundation
import CoreGraphics
#if canImport(AppKit)
import AppKit
#endif

public enum ImageProcessItem {
    case image(Image)
    case data(Data)
}


public protocol ImageProcessor {
    var identifier: String { get }
    
    @available(*, deprecated, message: "Deprecated. Implement the method with same name but with `KingfisherParsedOptionsInfo` instead.")
    func process(item: ImageProcessItem, options: KingfisherOptionsInfo) -> Image?
    
    func process(item: ImageProcessItem, options: KingfisherParsedOptionsInfo) -> Image?
}

extension ImageProcessor {
    public func process(item: ImageProcessItem, options: KingfisherOptionsInfo) -> Image? {
        return process(item: item, options: KingfisherParsedOptionsInfo(options))
    }
}
extension ImageProcessor {
    public func append(anouther: ImageProcessor) -> ImageProcessor {
        let newIdentifier = identifier.appending("|>\(anouther.identifier)")
        return GeneralPrpcessor(identifier: newIdentifier) { (item, options) -> Image? in
            if let image = self.process(item: item, options: options) {
                return anouther.process(item: .image(image), options: options)
            } else {
                return nil
            }
        }
    }
}

func ==(left: ImageProcessor, right: ImageProcessor) -> Bool {
    return left.identifier == right.identifier
}
func !==(lefT: ImageProcessor, right: ImageProcessor) -> Bool {
    return !(lefT == right)
}
typealias ProcessorImp = ((ImageProcessItem, KingfisherParsedOptionsInfo) -> Image?)
struct GeneralPrpcessor: ImageProcessor {
    let identifier: String
    let p: ProcessorImp
    func process(item: ImageProcessItem, options: KingfisherParsedOptionsInfo) -> Image? {
        return p(item, options)
    }
}

public struct DefaultImageProcessor:  ImageProcessor {
    public func process(item: ImageProcessItem, options: KingfisherParsedOptionsInfo) -> Image? {
        return nil
    }

    public static let `default` = DefaultImageProcessor()
    
    public var identifier: String = ""
    
    public init() {}

}
