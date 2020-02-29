//
//  Kingfisher.swift
//  KingFisher
//
//  Created by leven on 2020/2/25.
//  Copyright © 2020 leven. All rights reserved.
//

import Foundation
import ImageIO

#if os(macOS)
import AppKit
public typealias Image = NSImage
public typealias View = NSView
public typealias Color = NSColor
public typealias ImageView = NSImageView
public typealias Button = NSButton
#else
import UIKit
public typealias Image = UIImage
public typealias Color = UIColor
#if !os(watchOS)
public typealias ImageView = UIImageView
public typealias View = UIView
public typealias Button = UIButton
#else
import WatchKit
#endif
#endif

/// Wrapper for Kingfisher compatible types. This type provides an extension point for connivence methods in Kingfisher
public struct KingfisherWrapper<Base> {
    public let base: Base
    public init(_ base: Base) {
        self.base = base
    }
}

/// Represents an object type that is compatible with Kingfisher . You can use `kf` property to get a value in the namespace of Kingfisher.
public protocol KingfisherCompatible: AnyObject { }

/// Represents a value type that is compatible with Kingfisher. You can use `kf` property to get a value in the namespace of Kingfisher
public protocol KingfisherCompatibleValue {}

extension KingfisherCompatible {
    public var kf: KingfisherWrapper<Self> {
        get {
            return KingfisherWrapper(self)
        }
        set {}
    }
}

extension KingfisherCompatibleValue {
    public var kf: KingfisherWrapper<Self> {
        get { return KingfisherWrapper(self) }
        set {}
    }
}

extension Image: KingfisherCompatible {}
#if !os(watchOS)
extension ImageView: KingfisherCompatible {}
extension Button: KingfisherCompatible {}
#else
extension WKInterfaceImage: KingfisherCompatible { }
#endif
