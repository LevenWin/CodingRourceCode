//
//  File.swift
//  KingFisher
//
//  Created by leven on 2020/2/26.
//  Copyright © 2020 leven. All rights reserved.
//

import Foundation
#if os(macOS)
import APPKit
#else
import UIKit
#endif

extension Notification.Name {
    public static let KingfisherDidCleanDishCache = Notification.Name("com.onevcat.Kingfisher.KingfisherDidCleanDiskCache")
}
public let KingfisherDidCacheCleanedHashKey = "com.onevcat.Kingfisher.cleanedHash"

public enum CacheType {
    case none
    
    case memory
    
    case disk
    
    public var cached: Bool {
        switch self {
        case .none:
            return false
        default:
            return true
        }
    }
}
public struct CacheStoreResult {
    public let memoryCacheResult: Result<(), Never>
    
    public let diskCacheResult: Result<(), KingfisherError>
}

extension Image: CacheCostCalcuable {
    public var cacheCost: Int { return kf.cost }
}

extension Data: DataTransformable {
    public func toData() throws -> Data {
        return self
    }
    public static func fromData(_ data: Data) throws -> Data {
        return data
    }
    public static var empty: Data = Data()
}


public enum ImageCacheResult {
    
    case disk(Image)
    
    case memory(Image)
    
    case none
    
    public var image: Image? {
        switch self {
        case .disk(let image):
            return image
        case .memory(let image):
            return image
        case .none:
            return nil
        }
    }
    
    public var cacheType: CacheType {
        switch self {
        case .disk:
            return .disk
        case .memory:
            return .memory
        case .none:
            return .none
        }
    }
}

open class ImageCache {
    
    public static let `defaul` = ImageCache(name: "default")
    
    public let memoryStorage: MemoryStorage.Backend<Image>
    
    public let diskCache: DiskStorage.Backend<Data>
    
    private let ioQueue: DispatchQueue
    
    public typealias DiskCachePathClosure = (URL, String) -> URL
    
    public init(
        memoryStorage: MemoryStorage.Backend<Image>,
        diskStorage: DiskStorage.Backend<Data>
    ) {
        self.memoryStorage = memoryStorage
        self.diskCache = diskStorage
        let ioQueueName = "com.onevcat.Kingfisher.ImageCache.ioQueue.\(UUID().uuidString)"
        ioQueue = DispatchQueue(label: ioQueueName)
        
        let notifications: [(NSNotification.Name, Selector)]
        notifications = [
            (UIApplication.didReceiveMemoryWarningNotification, #selector(clearMemoryCache)),
            (UIApplication.willTerminateNotification, #selector(cleanExpiredDiskCache)),
            (UIApplication.didEnterBackgroundNotification, #selector(backgroundCleanExpiredDiskCache))
        ]
        notifications.forEach {
            NotificationCenter.default.addObserver(self, selector: $0.1, name: $0.0, object: nil)
        }
        
    }
    
    public convenience init(name: String) {
        try! self.init(name: name, cacheDirectoryURL: nil, diskCachePathClosure: nil)
    }
    
    public convenience init(name: String, cacheDirectoryURL: URL?, diskCachePathClosure: DiskCachePathClosure? = nil) throws {
        if name.isEmpty {
            fatalError("[Kingfisher] You should specify a name for the cache. A cache with empty name is not premitted")
        }
        
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        let costLimit = totalMemory/4
        let memoryStorage = MemoryStorage.Backend<Image>(config: .init(totalCostLimit: (costLimit > Int.max) ? Int.max : Int(costLimit)))
        var diskConfig = DiskStorage.Config(
            name: name, sizeLimit: 0, directory: cacheDirectoryURL
        )
        if let closure = diskCachePathClosure {
            diskConfig.cachePathBlock = closure
        }
        
        let diskStorage = try DiskStorage.Backend<Data>(config: diskConfig)
        diskConfig.cachePathBlock = nil
        self.init(memoryStorage: memoryStorage, diskStorage: diskStorage)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    open func store(
        _ image: Image,
        original: Data? = nil,
        forKey key: String,
        options: KingfisherParsedOptionsInfo,
        toDisk: Bool = true,
        completionHandler: ((CacheStoreResult) -> Void)? = nil
    ) {
        let idenfifier = options.processor.identifier
        let callbackQueue = options.callbackQueue
        let computedKey = key.computedKey(with: idenfifier)
        
        memoryStorage.storeNoThrow(value: image, forKey: computedKey, expiration: options.memoryCacheExpiration)
        guard toDisk else {
            if let completionHandler = completionHandler {
                let result = CacheStoreResult(memoryCacheResult: .success(()), diskCacheResult: .success(()))
                callbackQueue.execute {
                    completionHandler(result)
                }
            }
            return
        }
        
        ioQueue.async {
            let serializer = options.cacheSerializer
            if let data = serializer?.data(with: image, original: original) {
                self.syncStoreToDisk(data, forKey: key, processorIdentifier: idenfifier, callbackQueue: callbackQueue, expiration: options.diskCacheExpiration, completionHandler: completionHandler)
            } else {
                guard let completionHdnler = completionHandler else { return }
                let diskError = KingfisherError.cacheError(reason: .cannotSerializeImage(image: image, original: original, serializer: serializer!))
                let result = CacheStoreResult(memoryCacheResult: .success(()), diskCacheResult: .failure(diskError))
                callbackQueue.execute {
                    completionHdnler(result)
                }
            }
        }
        
    }
    
    open func store(
        _ image: Image,
        original: Data? = nil,
        forKey key: String,
        processorIndetifier identifier: String = "",
        cacheSerializer serializer: CacheSerializer = DefaultCacheSerializer.default,
        toDisk: Bool = true,
        callbackQueue: CallbackQueue = .untouch,
        completionHandler: ((CacheStoreResult) -> Void)? = nil
    )
    {
        struct TempProcessor: ImageProcessor {
            let identifier: String
            func process(item: ImageProcessItem, options: KingfisherParsedOptionsInfo) -> Image? {
                return nil
            }
        }
        
        let options = KingfisherParsedOptionsInfo([
            .processor(TempProcessor(identifier: identifier)),
            .cacheSerializer(serializer),
            .callbackQueue(callbackQueue)
        ])
        store(image, original: original, forKey: key, options: options, toDisk: toDisk, completionHandler: completionHandler)
    }
    
    private func syncStoreToDisk(
        _ data: Data,
        forKey key: String,
        processorIdentifier identifier: String = "",
        callbackQueue: CallbackQueue = .untouch,
        expiration: StorageExpiration? = nil,
        completionHandler: ((CacheStoreResult) -> Void)? = nil
    )
    {
        let computedKey = key.computedKey(with: identifier)
        
        let result: CacheStoreResult
        do {
            try self.diskCache.store(value: data, forKey: computedKey, expiration: expiration)
            result = CacheStoreResult(memoryCacheResult: .success(()), diskCacheResult: .success(()))
        } catch {
            let diskError: KingfisherError
            if let error = error as? KingfisherError {
                diskError = error
            } else {
                diskError = .cacheError(reason: .cannotConvertToData(object: data, error: error))
            }
            result = CacheStoreResult(
                memoryCacheResult: .success(()), diskCacheResult: .failure(diskError))
        }
        if let completionHandler = completionHandler {
            callbackQueue.execute {
                completionHandler(result)
            }
        }
    }
    
    open func removeImage(
        forKey key: String,
        processorIdentifier identifier: String = "",
        forMeomry: Bool = true,
        fromDisk: Bool = true,
        callbackQueue: CallbackQueue = .untouch,
        completionHandler: (() ->Void)? = nil)
    {
        let computedKey = key.computedKey(with: identifier)
        if forMeomry {
            try? memoryStorage.remove(forKey: computedKey)
        }
        if fromDisk {
            ioQueue.async {
                try? self.diskCache.remove(forKey: computedKey)
                if let completionHandler = completionHandler {
                    callbackQueue.execute {
                        completionHandler()
                    }
                }
            }
        } else {
            if let completionHandler =  completionHandler {
                callbackQueue.execute {
                    completionHandler()
                }
            }
        }
    }
    
    func retrieveImage(
        forKey key: String,
        options: KingfisherParsedOptionsInfo,
        callbackQueue: CallbackQueue = .untouch,
        completionHandler: ((Result<ImageCacheResult, KingfisherError>) -> Void)?
    )
    {
        guard let completionHandler = completionHandler else {
            return
        }
        if let image = retrieveImageInMemoryCache(forKey: key, options: options) {
            let image = options.imageModifier?.modify(image) ?? image
            callbackQueue.execute {
                completionHandler(.success(.memory(image)))
            }
        } else if options.fromMemoryCacheOrRefresh {
            callbackQueue.execute {
                completionHandler(.success(.none))
            }
        } else {
            
        }
    }
    
    open func retrieveImage(forKey key: String, options: KingfisherOptionsInfo? = nil, callbackQueue: CallbackQueue = .untouch, completionHandler: ((Result<ImageCacheResult, KingfisherError>) -> Void)?)
    {
        retrieveImage(forKey: key, options: KingfisherParsedOptionsInfo(options), callbackQueue: callbackQueue, completionHandler: completionHandler)
    }
    
    func retrieveImageInMemoryCache(
        forKey key: String,
        options: KingfisherParsedOptionsInfo
    ) -> Image? {
        let computedKey = key.computedKey(with: options.processor.identifier)
        return memoryStorage.value(forKey: computedKey, extendingExpiration: options.memoryCacheAccessExtendingExpiration)
    }
    open func retrieveImageInMemoryCache(
        forKey key: String,
        options: KingfisherOptionsInfo? = nil
    ) -> Image?
    {
        return retrieveImageInMemoryCache(forKey: key, options: KingfisherParsedOptionsInfo(options))
    }
    
    func retrieveImageInDiskCache(
        forKey key: String,
        options: KingfisherParsedOptionsInfo,
        callbackQueue: CallbackQueue = .untouch,
        completionHandler: @escaping (Result<Image?, KingfisherError>) -> Void)
    {
        let computedKey = key.computedKey(with: options.processor.identifier)
        let loadingQueue: CallbackQueue = options.loadDiskFileSynchronously ? .untouch : .dispatch(ioQueue)
        loadingQueue.execute {
            do {
                var image: Image? = nil
                if let data = try self.diskCache.value(forKey: computedKey) {
                    image = options.cacheSerializer?.image(with: data, options: options)
                }
                callbackQueue.execute {
                    completionHandler(.success(image))
                }
            } catch {
                if let error = error as? KingfisherError {
                    callbackQueue.execute {
                        completionHandler(.failure(error))
                    }
                } else {
                    assertionFailure("The internal thrown error should be `KingfisherError`.")
                }
            }
        }
    }
    
    
    
    @objc func clearMemoryCache() {
        try? memoryStorage.removeAll()
    }
    
    open func cleanDiskCache(completion handler: (() -> ())? = nil)
    {
        ioQueue.async {
            do {
                try  self.diskCache.removeAll()
            } catch _ {}
            if let handler = handler {
                DispatchQueue.main.async {
                    handler()
                }
            }
        }
    }
    
    @objc func cleanExpiredDiskCache() {
        memoryStorage.removeExpired()
    }
    
//    @objc func backgroundCleanExpiredDiskCache() {
//        cleanExpiredDiskCache()
//    }
    
    open func cleanExpiredDiskCache(completion handler: (() -> Void)? = nil)
    {
        ioQueue.async {
            do {
                var removed: [URL] = []
                let removedExpired = try  self.diskCache.removeExpiredValues()
                removed.append(contentsOf: removedExpired)
                
                let removedSizeExceed = try self.diskCache.removeSizeExceededValues()
                removed.append(contentsOf: removedSizeExceed)
                if !removed.isEmpty {
                    DispatchQueue.main.async {
                        let cleanedHashed = removed.map { $0.lastPathComponent }
                        NotificationCenter.default.post(name: .KingfisherDidCleanDishCache, object: self, userInfo: [KingfisherDidCacheCleanedHashKey: cleanedHashed])
                    }
                }
                if let handler = handler {
                    DispatchQueue.main.async {
                        handler()
                    }
                }
            } catch {}
        }
    }
    
    #if !os(macOS) && !os(watchOS)
    @objc public func backgroundCleanExpiredDiskCache() {
        guard let sharedApplication = KingfisherWrapper<UIApplication>.shared else { return }
        
        func endBackgroundTask(_ task: inout UIBackgroundTaskIdentifier) {
            sharedApplication.endBackgroundTask(task)
            #if swift(>=4.2)
            task = UIBackgroundTaskIdentifier.invalid
            #else
            task = UIBackgroundTaskInvalid
            #endif
         }
        var backgroundTask: UIBackgroundTaskIdentifier!
        backgroundTask = sharedApplication.beginBackgroundTask(expirationHandler: {
            endBackgroundTask(&backgroundTask!)
        })
        cleanExpiredDiskCache {
            endBackgroundTask(&backgroundTask)
        }
    }
    #endif
    open func imageCachedType(
        forKey key: String,
        processorIdentifier identifier: String = DefaultImageProcessor.default.identifier
    ) -> CacheType {
        let computedKey = key.computedKey(with: identifier)
        if memoryStorage.isCached(forKey: computedKey) { return .memory }
        if diskCache.isCached(forKey: computedKey) { return .disk }
        return .none
    }
    
    public func isCached(
        forKey key: String,
        processorIdentifier identifier: String = DefaultImageProcessor.default.identifier
    ) -> Bool
    {
        return imageCachedType(forKey: key, processorIdentifier: identifier).cached
    }
    
    open func hash(
        forKey key: String,
        processorIdentifier identifier: String = DefaultImageProcessor.default.identifier
    ) -> String
    {
        let computedKey = key.computedKey(with: identifier)
        return diskCache.cacheFileName(forKey: computedKey)
    }
    open func calculateDiskStorageSize(completion handler: @escaping ((Result<UInt, KingfisherError>) -> Void))
    {
        ioQueue.async {
            do {
                let size = try self.diskCache.totalSize()
                DispatchQueue.main.async {
                    handler(.success(size))
                }
            } catch {
                if let error = error as? KingfisherError {
                    DispatchQueue.main.async {
                        handler(.failure(error))
                    }
                } else {
                    assertionFailure("The internal thrown error should be a `KingfisherError`")
                }
            }
            
        }
    }
    
    open func cachePath(
        forKey key: String,
        processorIdentifier identifier: String = DefaultImageProcessor.default.identifier
    ) -> String {
        let computedKey = key.computedKey(with: identifier)
        return diskCache.cacheFileURL(forKey: computedKey).path
    }
}
extension Dictionary {
    func keysSortedByValue(
        _ isOrderedBefore: (Value, Value) -> Bool
    ) -> [Key] {
        return Array(self).sorted { isOrderedBefore($0.1, $1.1)}.map { $0.0 }
    }
}
#if !os(macOS) && !os(watchOS)
extension UIApplication: KingfisherCompatible {}
extension KingfisherWrapper where Base: UIApplication {
    public static var shared: UIApplication? {
        let selector = NSSelectorFromString("sharedApplication")
        guard Base.responds(to: selector) else {
            return nil
        }
        return Base.perform(selector)?.takeUnretainedValue() as? UIApplication
    }
}
#endif

extension String {
    func computedKey(with identifier: String) -> String {
        if identifier.isEmpty {
            return self
        } else {
            return appending("@\(identifier)")
        }
    }
}

extension ImageCache {
    
    @available(*, deprecated, message: "Use `init(name:cacheDirectoryURL:diskCachePathClosure:)` instead", renamed: "init(name:cacheDirectoryURL:diskCachedPathClosure:)")
    public convenience init(
        name: String,
        path: String?,
        diskCachePathClosure: DiskCachePathClosure? = nil
    ) throws
    {
        let directoryURL = path.flatMap { URL(string: $0) }
        try self.init(name: name, cacheDirectoryURL: directoryURL, diskCachePathClosure: diskCachePathClosure)
    }
}







