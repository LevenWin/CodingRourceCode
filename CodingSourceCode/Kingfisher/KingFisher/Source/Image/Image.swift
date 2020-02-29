//
//  Image.swift
//  KingFisher
//
//  Created by leven on 2020/2/25.
//  Copyright © 2020 leven. All rights reserved.
//

import Foundation
#if os(macOS)
import AppKit
private var imagesKey: Void?
private var durationKey: Void?
#else
import UIKit
import MobileCoreServices
private var imageSourceKey: Void?
#endif

#if !os(watchOS)
import CoreImage
#endif
import CoreGraphics
import ImageIO
private var animatedImageDataKey: Void?

extension KingfisherWrapper where Base: Image {
    private(set) var animatedImageData: Data? {
        get { return getAssociatedObject(base, &animatedImageDataKey)}
        set { setRetainedAssociatedObject(base, &animatedImageDataKey, newValue)}
    }
    #if os(macOS)
    var cgImage: CGImage? {
        return base.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
    var scale: CGFloat {
        return 1.0
    }
    private(set) var images: [Image]? {
        get { return getAssociatedObject(base, &imagesKey) }
        set { setRetainedAssociatedObject(base, &imagesKey, newValue) }
    }
    
    private(set) var duration: TimeInterval {
        get { return getAssociatedObject(base, &durationKey) ?? 0.0 }
        set { setRetainedAssociatedObject(base, &durationKey, newValue) }
    }
    
    var size: CGSize {
        return base.representations.reduce(.zero) { size, rep in
            let width = max(size.width, CGFloat(rep.pixelsWide))
            let height = max(size.height, CGFloat(rep.pixelsHigh))
            return CGSize(width: width, height: height)
        }
    }
    #else
    var cgImage: CGImage? { return base.cgImage }
    var scale: CGFloat { return base.scale }
    var images: [Image]? { return base.images }
    var duration: TimeInterval { return base.duration }
    var size: CGSize { return base.size }
    private(set) var imageSource: CGImageSource? {
        get { return getAssociatedObject(base, &imageSourceKey)}
        set { setRetainedAssociatedObject(base, &imageSourceKey, newValue)}
    }
    #endif
    
    var cost: Int {
        let pixel = Int(size.width * size.height * scale * scale)
        guard  let cgImage = cgImage else {
            return pixel * 4
        }
        return pixel * cgImage.bitsPerPixel/8
    }
    
}

extension KingfisherWrapper where Base: Image {
    static func image(cgImage: CGImage, scale: CGFloat, refImage: Image?) -> Image {
        return Image(cgImage: cgImage, scale: scale, orientation: refImage?.imageOrientation ?? .up)
    }
    
    public var normalized: Image {
        guard images == nil else {
            return base.copy() as! Image
        }
        guard base.imageOrientation  != .up else {
            return base.copy() as! Image
        }
        #warning("TODO")
        return base.copy() as! Image
    }
    
    func fixOrientation(in context: CGContext) {
        var transform = CGAffineTransform.identity
        
        let orientation = base.imageOrientation
        switch orientation {
        case .down, .downMirrored:
            transform = transform.translatedBy(x: size.width, y: size.height)
            transform = transform.rotated(by: .pi)
        case .left, .leftMirrored:
            transform = transform.translatedBy(x: size.width, y: size.height)
            transform = transform.rotated(by: .pi/2.0)
        case .right, .rightMirrored:
            transform = transform.translatedBy(x: 0, y: size.height)
            transform = transform.rotated(by: .pi / -2.0)
        case .up, .upMirrored:
            break
        }
        switch orientation {
        case .upMirrored, .downMirrored:
            transform = transform.translatedBy(x: size.width, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        case .leftMirrored, .rightMirrored:
            transform = transform.translatedBy(x: size.height, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        case .up, .down, .left, .right:
            break
        }
        context.concatenate(transform)
//        switch orientation {
//        case .left, .leftMirrored, .right, .rightMirrored:
//            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.height, height: size.width))
//        default:
//            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
//        }
    }
}



extension KingfisherWrapper where Base: Image {
    
    
    public func pngRepresentation() -> Data? {
//        #if os(macOS)
//        guard let cgImage = cgImage else {
//            return nil
//        }
//        let rep = NSBitmapImageRep(cgImage: cgImage)
//        return rep.representation(using: .png, properties: [:])
//        #else
//        #if swift(>=4.2)
        return base.pngData()
//        #else
//        return UIImagePNGRepresentation(base)
//        #endif
    }
    
        
    
        
    public func jpegRepresentation(compressionQuality: CGFloat) -> Data? {
        #if os(macOS)
            guard let cgImage = cgImage else {
                return nil
            }
            let rep = NSBitmapImageRep(cgImage: cgImage)
            return rep.representation(using:.jpeg, properties: [.compressionFactor: compressionQuality])
        #else
            #if swift(>=4.2)
            return base.jpegData(compressionQuality: compressionQuality)
            #else
            return UIImageJPEGRepresentation(base, compressionQuality)
            #endif
        #endif
        
    }
    
    
        
        
        
    public func gifRepresentation() -> Data? {
        return animatedImageData
    }
    
    public func data(format: ImageFormat) ->  Data? {
        let data: Data?
        switch format {
        case .PNG:
            data = pngRepresentation()
        case .JPEG:
            data = jpegRepresentation(compressionQuality: 1.0)
        case .GIF:
            data = gifRepresentation()
        case .unknown:
            data = normalized.kf.pngRepresentation()
        }
        return data
    }
}

extension KingfisherWrapper where Base: Image {
    public static func animatedImage(data: Data, options: ImageCreatingOptions) -> Image? {
        let info: [String: Any] = [
            kCGImageSourceShouldCache as String: true,
            kCGImageSourceTypeIdentifierHint as String: kUTTypeGIF
        ]
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, info as CFDictionary) else { return nil }
        
        var image: Image?
        if options.preloadAll || options.onlyFirstFrame {
            guard let animatedImage = GIFAnimatedImage(from: imageSource, for: info, options: options) else { return nil }
            if options.onlyFirstFrame {
                image = animatedImage.images.first
            } else {
                let duration = options.duration <= 0.0 ? animatedImage.duration : options.duration
                image = Image.animatedImage(with: animatedImage.images, duration: duration)
            }
            image?.kf.animatedImageData = data
        } else {
            image = Image(data: data, scale: options.scale)
            var kf = image?.kf
            kf?.imageSource = imageSource
            kf?.animatedImageData = data
        }
        return image
    }

    public static func image(data: Data, options: ImageCreatingOptions) -> Image? {
        var image: Image?
        switch data.kf.imageFormat {
        case .JPEG:
            image = Image(data: data, scale: options.scale)
        case .PNG:
            image = Image(data: data, scale: options.scale)
        case .GIF:
            image = KingfisherWrapper.animatedImage(data: data, options: options)
        case .unknown:
            image = Image(data: data, scale: options.scale)
        }
        return image
    }
    
    public static func downsampledImage(data: Data, to pointSize: CGSize, scale: CGFloat) -> Image? {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, imageSourceOptions) else {
            return nil
        }
        
        let maxDimensionInPixels = max(pointSize.width, pointSize.height) * scale
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimensionInPixels] as CFDictionary
        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions) else {
            return nil
        }
        return KingfisherWrapper.image(cgImage: downsampledImage, scale: scale, refImage: nil)
    }
}
