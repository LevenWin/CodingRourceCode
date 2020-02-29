//
//  GIFAnimatedImage.swift
//  KingFisher
//
//  Created by leven on 2020/2/25.
//  Copyright © 2020 leven. All rights reserved.
//

import Foundation
import ImageIO
/// Represents a set of image creating options used in Kingfisher.
public struct ImageCreatingOptions {
    /// The target scale of image needs to be created
    public let scale: CGFloat
    /// The expected animation duration if an animated image being created
    public let duration: TimeInterval
    /// For an animated image , whether or not all frames should be loaded before displaying
    public let preloadAll: Bool
    
    ///For animated image , whether or note only the first image should be loaded as a static image, it is useful for preview purpose of ananimated image.
    public let onlyFirstFrame: Bool
    
    public init(
        scale: CGFloat = 1.0,
        duration: TimeInterval = 0.0,
        preloadAll: Bool = false,
        onlyFirstFrame: Bool = false)
    {
        self.scale = scale
        self.duration = duration
        self.preloadAll = preloadAll
        self.onlyFirstFrame = onlyFirstFrame
    }
}
/// Represents the decoding for a GIF image .This class extracts frames from an `imageSource`, then hold the image for later use
class GIFAnimatedImage {
    let images: [Image]
    let duration: TimeInterval
    
    init?(from imageSource: CGImageSource, for info: [String: Any], options: ImageCreatingOptions) {
        let frameCount = CGImageSourceGetCount(imageSource)
        var images = [Image]()
        var gifDuration = 0.0
        for i in 0..<frameCount {
            guard let imageRef = CGImageSourceCreateImageAtIndex(imageSource, i, info as CFDictionary) else {
                return nil
            }
            if frameCount == 1 {
                gifDuration = .infinity
            } else {
                gifDuration = GIFAnimatedImage.getFrameDuration(from: imageSource, at: i)
            }
//            images.append(KingfisherWrapper.i)
        }
        self.images = images
        self.duration = gifDuration
    }
    
    // Calculates frame duration for a gift frame out of the kCGImagePropertyGIFDictionary dictionary
    static func getFrameDuration(from gifInfo: [String: Any]?) -> TimeInterval {
        let defaultFrameDuration = 0.1
        guard  let gifInfo = gifInfo else {
            return defaultFrameDuration
        }
        
        let unclampedDelayTime = gifInfo[kCGImagePropertyGIFUnclampedDelayTime as String] as? NSNumber
        let delayTime = gifInfo[kCGImagePropertyGIFDelayTime as String] as? NSNumber
        let duration = unclampedDelayTime ?? delayTime
        guard let frameDuration = duration else {
            return defaultFrameDuration
        }
        return frameDuration.doubleValue > 0.011 ? frameDuration.doubleValue : defaultFrameDuration
    }
    
    static func getFrameDuration(from imageSource: CGImageSource, at index: Int) -> TimeInterval {
        guard let properties = CGImageSourceCopyProperties(imageSource, nil) as? [String: Any] else { return 0.0 }
        let gifInto = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any]
        return getFrameDuration(from: gifInto)
    }
}
