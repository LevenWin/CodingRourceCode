//
//  ExtensionHelpers.swift
//  KingFisher
//
//  Created by leven on 2020/2/25.
//  Copyright © 2020 leven. All rights reserved.
//

import Foundation

extension Float {
    var isEven: Bool {
        return truncatingRemainder(dividingBy: 2.0) == 0
    }
}

#if canImport(AppKit)
import AppKit

extension NSBezirPath {
    
}

extension Image {
    
}
#endif

#if canImport(UIKit)
import UIKit


#endif

extension Date {
    var isPast: Bool {
        return isPast(referenceDate: Date())
    }
    
    var isFuture: Bool {
        return !isPast
    }
    
    func isPast(referenceDate: Date) -> Bool {
        return timeIntervalSince(referenceDate) <= 0
    }
    func isFuture(referenceDate: Date) -> Bool {
        return !isPast(referenceDate: referenceDate)
    }
    
    // `Date` in memory is a wrap for `TimeInterval`. But in file attribute it can only accept `Int` number.
    // By default the system will `round` it. But it is not friendly for testing purpose.
    // So we always `ceil` the value when used for file attributes.
    var filterAttributeDate: Date {
        return Date(timeIntervalSince1970: ceil(timeIntervalSince1970))
    }
}
