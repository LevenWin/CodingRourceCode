//
//  File.swift
//  KingFisher
//
//  Created by leven on 2020/2/26.
//  Copyright © 2020 leven. All rights reserved.
//

import Foundation

public protocol ImageModifier {
    func modify(_ image: Image) -> Image
}

public struct AnyImageModifier: ImageModifier {
    let block: (Image) throws -> Image
    
    public init(modify: @escaping (Image) throws -> Image) {
        block = modify
    }
    public func modify(_ image: Image) -> Image {
         return (try? block(image)) ?? image
    }
}

#if os(iOS) || os(tvOS) || os(watchOS)
import UIKit

public struct RenderingModeImageModifier: ImageModifier {
    public let renderingMode: UIImage.RenderingMode
    
    public init(renderingMode: UIImage.RenderingMode = .automatic) {
        self.renderingMode = renderingMode
    }
    public func modify(_ image: Image) -> Image {
        return image.withRenderingMode(renderingMode)
    }
}

public struct FlipsForRightToLeftLayoutDirectionImageModifier: ImageModifier {
    public init() {}
    public func modify(_ image: Image) -> Image {
        return image.imageFlippedForRightToLeftLayoutDirection()
    }
}

public struct AlignmentRectInsetsImageModifier: ImageModifier {
    public let alignmentInsets: UIEdgeInsets
    public init(alignmentInsets: UIEdgeInsets) {
        self.alignmentInsets = alignmentInsets
    }
    public func modify(_ image: Image) -> Image {
        return image.withAlignmentRectInsets(alignmentInsets)
    }
}
#endif
