//
//  Storage.swift
//  KingFisher
//
//  Created by leven on 2020/2/24.
//  Copyright © 2020 leven. All rights reserved.
//

import Foundation

/// Constants for some time intervals
struct TimeConstants {
    static let secondsInOneMinute = 60
    static let minutesInOneHour = 60
    static let hoursInOneDay = 24
    static let secondsInOneDay = secondsInOneMinute * minutesInOneHour * hoursInOneDay
}

/// Represents the expiration strategy used in storage.
///
/// - never: The item never expires.
/// - seconds: The item expires after a time duration of given seconds from now
/// - days: The item expires after a time duration of given days from now.
/// - date: The item expires after a given date.

public enum StorageExpiration {
    /// The item never expires.
    case never
    /// The item expires after a time duration of given seconds from now.
    case seconds(TimeInterval)
    /// The item expires after a time duration of given days from now.
    case days(Int)
    /// The item expires after a given date
    case date(Date)
    /// Indicates the item is already expired,Use thie to skip cache.
    case expired
    
    func estimatedExpirationSince(_ date: Date) -> Date {
        switch self {
        case .never:
            return .distantFuture
        case .seconds(let seconds):
            return date.addingTimeInterval(seconds)
        case .days(let days):
            return date.addingTimeInterval(TimeInterval(TimeConstants.secondsInOneDay * days))
        case .date(let ref):
            return ref
        case .expired:
            return .distantPast
        }
    }
    
    var estimatedExpirationSinceNow: Date {
        return estimatedExpirationSince(Date())
    }
    
    var timeInterval: TimeInterval {
        switch self {
        case .never:
            return .infinity
        case .seconds(let seconds):
            return seconds
        case .days(let day):
            return TimeInterval(TimeConstants.secondsInOneDay * day)
        case .expired:
            return -(.infinity)
        case .date(let ref):
            return ref.timeIntervalSinceNow
            
        }
    }
    
    var isExpired: Bool {
        return timeInterval <= 0
    }
}

/// Represents the expiration extending stragegy used in storage to after access
///
/// - none: The item expires after the original time, without extending after access.
/// - cacheTime: The item expiration extends by the original cache time after access.
/// - expirationTime: The item expiration extends by the priovided time after each access.
public enum ExpirationExtending {
    /// The item expires after the original time, without extending after success/
    case none
    /// The item expiration extends by original cache time afger each access.
    case cacheTime
    /// The item expiration extends by the provided time after each access.
    case expirationTime(_ expiration: StorageExpiration)
}

/// Represents types which cost in memory can be calculated.
public protocol CacheCostCalcuable {
    var cacheCost: Int { get }
}

/// Represents types which can be converted to and from data.
public protocol DataTransformable {
    func toData() throws -> Data
    static func fromData(_ data: Data) throws -> Self
    static var empty: Self { get }
}


