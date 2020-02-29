//
//  DiskStorage.swift
//  KingFisher
//
//  Created by leven on 2020/2/25.
//  Copyright © 2020 leven. All rights reserved.
//

import Foundation
/// Represents a set of conception related to storage which stores a certain type of value in disk.
/// Thie is a namespace for the disk storage types. A `Backend` with certain `Config` will be used to describe the storage. See these composed types for more information.
public enum DiskStorage {
    
    /// Represents a storage back-end for the `DiskStorage`. The value is serialized to data
    /// and stored as file in the file system under a specified location.
    ///
    /// You can config a `DiskStorage.Backend` in its initializer by passing a `DiskStorage.Config` value.
    /// or modifying the `config` property after it being created. `DiskStorage` will use files attributes to keep track of a file for its expiration or size limiation.
    public class Backend<T: DataTransformable> {
        /// The config used for this disk  storage
        public var config: Config
        
        /// The final storage URL on disk , with `name` and `cachePathBlock` considered
        public let directoryURL: URL
        

        let metaChangingQueue: DispatchQueue
        
        /// Creates a disk storage with the given `DiskStorage.Config`
        /// -   Parameters config: The config used for this disk storage
        /// -   Throws: An error if the folder for storage cannot be got or created
        public init(config: Config) throws {
            self.config = config
            let url: URL
            if let directory = config.directory {
                url = directory
            } else {
                url = try config.fileManager.url(
                    for: .cachesDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: true)
            }
            
            let cacheName = "com.onevcat.Kingfisher.ImageCache.\(config.name)"
            directoryURL = config.cachePathBlock(url, cacheName)
            metaChangingQueue = DispatchQueue(label: cacheName)
            try prepareDirectory()
        }
        
        // Creates the storage folder
        func prepareDirectory() throws {
            let fileManager = config.fileManager
            let path = directoryURL.path
            guard !fileManager.fileExists(atPath: path) else {
                return
            }
            do {
                try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
            } catch {
//                throw Error
            }
        }
        
        func store(
            value: T,
            forKey key: String,
            expiration: StorageExpiration? = nil) throws
        {
            let expiration = expiration ??  config.expiration
            
            // The expiration indicates that already expired, no need to store
            guard !expiration.isExpired else {
                return
            }
            var data: Data
            do {
                data = try value.toData()
            } catch {
                throw KingfisherError.cacheError(reason: .cannotConvertToData(object: value, error: error))
            }
            let fileURL = cacheFileURL(forKey: key)
            let now = Date()
            let attributes: [FileAttributeKey : Any] = [
                // The last access date
                .creationDate: now.filterAttributeDate,
                // The estimated expiration date.
                .modificationDate: expiration.estimatedExpirationSinceNow.filterAttributeDate
            ]
            config.fileManager.createFile(atPath: fileURL.path, contents: data, attributes: attributes)
        }
        
        func value(forKey key: String) throws -> T? {
            return nil
            
        }
        
        func value(forKey key: String, referenceDate: Date, actuallyLoad: Bool) throws -> T? {
            let fileManager = config.fileManager
            let fileURL = cacheFileURL(forKey: key)
            let filePath = fileURL.path
            guard fileManager.fileExists(atPath: filePath) else { return nil }
            var meta: FileMeta
            do {
                let resourceKeys: Set<URLResourceKey> = [.contentModificationDateKey, .creationDateKey]
                meta = try FileMeta(fileURL: fileURL, resourceKeys: resourceKeys)
            } catch {
                throw KingfisherError.cacheError(
                    reason: .invalidURLResource(error: error, key: key, url: fileURL))
            }
            
            if meta.expired(referenceDate: referenceDate) {
                return nil
            }
            if !actuallyLoad { return T.empty }
            do {
                let data = try Data(contentsOf: fileURL)
                let obj = try T.fromData(data)
                metaChangingQueue.async {
                    meta.extendExpiration(with: fileManager)
                }
                return obj
            } catch {
                throw KingfisherError.cacheError(reason: .cannotLoadDataFromDisk(url: fileURL, error: error))

            }
        }
        func isCached(forKey key: String) -> Bool {
//            return isCached(forKey: key)
            return false
        }
        
        func isCached(forKey key: String, referenceDate: Date) -> Bool {
            do {
                guard let _ = try value(forKey: key, referenceDate: referenceDate, actuallyLoad: false) else {
                    return false
                }
                return true
            } catch {
                return false
            }
        }
        
        func remove(forKey key: String) throws {
            let fileURL = cacheFileURL(forKey: key)
            try removeFile(at: fileURL)
        }
        
        func removeFile(at url: URL) throws {
            try config.fileManager.removeItem(at: url)
        }
        func removeAll() throws {
            try removeAll(skipCreatingDirectory: false)
        }
        
        func removeAll(skipCreatingDirectory: Bool) throws {
            try config.fileManager.removeItem(at: directoryURL)
            if !skipCreatingDirectory {
                try prepareDirectory()
            }
        }
        
        func allFileURLs(for propertyKeys: [URLResourceKey]) throws -> [URL] {
            let fileManager = config.fileManager
            guard let directoryEnumerator = fileManager.enumerator(at: directoryURL, includingPropertiesForKeys: propertyKeys, options: .skipsHiddenFiles) else {
                throw KingfisherError.cacheError(reason: .fileEnumeratorOrCreationFailed(url: directoryURL))
            }
            guard let urls = directoryEnumerator.allObjects as? [URL] else {
                throw KingfisherError.cacheError(reason: .invalidFileEnumeratorORContent(url: directoryURL))

            }
            return urls
        }
        
        func removeExpiredValues(referenceDate: Date = Date()) throws -> [URL] {
            let propertyKeys: [URLResourceKey] = [
                .isDirectoryKey,
                .contentModificationDateKey
            ]
            let urls = try allFileURLs(for: propertyKeys)
            let keys = Set(propertyKeys)
            let expriedFiles = urls.filter { fileURL in
                do {
                    let meta = try FileMeta(fileURL: fileURL, resourceKeys: keys)
                    if meta.isDirectory {
                        return false
                    }
                    return meta.expired(referenceDate: referenceDate)
                } catch {
                    return true
                }
            }
            try expriedFiles.forEach {
                try removeFile(at: $0)
            }
            return expriedFiles
        }
        
        func removeSizeExceededValues() throws -> [URL] {
            if config.sizeLimit == 0 { return [] }
            
            var size = try totalSize()
            if size < config.sizeLimit { return [] }
            let propertyKeys: [URLResourceKey] = [
                .isDirectoryKey,
                .creationDateKey,
                .fileSizeKey
            ]
            let keys = Set(propertyKeys)
            let urls = try allFileURLs(for: propertyKeys)
            var pendings: [FileMeta] = urls.compactMap { (fileURL) in
                guard let meta = try? FileMeta(fileURL: fileURL, resourceKeys: keys) else {
                    return nil
                }
                return meta
            }
            pendings.sort(by: FileMeta.lastAccessDate)
            
            var removed: [URL] = []
            let target = config.sizeLimit / 2
            while size > target, let meta = pendings.popLast() {
                size -= UInt(meta.fileSize)
                try removeFile(at: meta.url)
                removed.append(meta.url)
            }
            return removed
        }
        
        func totalSize() throws -> UInt {
            let propertyKeys: [URLResourceKey] = [.fileSizeKey]
            let urls = try allFileURLs(for: propertyKeys)
            let keys = Set(propertyKeys)
            let totalSize: UInt = urls.reduce(0) { (size, fileUrl) in
                do {
                    let meta = try FileMeta(fileURL: fileUrl, resourceKeys: keys)
                    return size + UInt(meta.fileSize)
                } catch {
                    return size
                }
            }
            
            return totalSize
        }
        
        /// The URL of the cached file with a given computed `key`.
        ///
        ///- Note:
        /// thie methods does not guarantee there is an image already cached in the returned URL, it just give your the URL that image should be if it exits in disk storage.with the give key.
        /// - Parameters key: The final computed key used when caching the image Please not that usually this is not the `cacheKey` of an image `Source` . It is the computed key with processor idendifier considered.
        public func cacheFileURL(forKey key: String) -> URL {
            let fileName = cacheFileName(forKey: key)
            return directoryURL.appendingPathComponent(fileName)
        }
        
        public func cacheFileName(forKey key: String) -> String {
            return key
//            if config.usesHashedFileName {
//                let hashedKey = key.kf.md5
//                if let ext = config.pathExtension {
//                    return "\(hashedKey).\(ext)"
//                }
//                return hashedKey
//            } else {
//                if let ext = config.pathExtension {
//                    return "\(key).\(ext)"
//                }
//                return key
//            }
        }
    }
}

extension DiskStorage {
    public struct Config {
        public var sizeLimit: UInt
        
        public var expiration: StorageExpiration = .days(7)
        
        public var pathExtension: String? = nil
        
        public var usesHashedFileName = true
        
        let name: String
        let fileManager: FileManager
        let directory: URL?
        
        var cachePathBlock: ((_ directory: URL, _ cacheName: String) -> URL)! = {
            (directory, cacheName) in
            return directory.appendingPathComponent(cacheName, isDirectory: true)
        }
        
        public init(
            name: String,
            sizeLimit: UInt,
            fileManager: FileManager = .default,
            directory: URL? = nil) {
            self.name = name
            self.fileManager = fileManager
            self.directory = directory
            self.sizeLimit = sizeLimit
        }
    }
}

extension DiskStorage {
    struct FileMeta {
        let url: URL
        let lastAccessDate: Date?
        let estimatedExpirationDate: Date?
        let isDirectory: Bool
        let fileSize: Int
        static func lastAccessDate(lhs: FileMeta, rhs: FileMeta) -> Bool {
            return lhs.lastAccessDate ?? .distantPast > rhs.lastAccessDate ?? .distantPast
        }
        
        init(fileURL: URL, resourceKeys: Set<URLResourceKey>) throws {
            let meta = try fileURL.resourceValues(forKeys: resourceKeys)
            self.init(
                fileURL: fileURL,
                lastAccessDate:
                meta.creationDate,
                estimatedExpirationDate: meta.contentModificationDate,
                isDirectory: meta.isDirectory ?? false,
                fileSize: meta.fileSize ?? 0)
        }
        
        init(
            fileURL: URL,
            lastAccessDate: Date?,
            estimatedExpirationDate: Date?,
            isDirectory: Bool,
            fileSize: Int
             ) {
            self.url = fileURL
            self.lastAccessDate = lastAccessDate
            self.estimatedExpirationDate = estimatedExpirationDate
            self.isDirectory = isDirectory
            self.fileSize = fileSize
        }
        
        func expired(referenceDate: Date) -> Bool {
            return estimatedExpirationDate?.isPast(referenceDate: referenceDate) ?? true
        }
        func extendExpiration(with fileManager: FileManager) {
            guard let lastAccessData = lastAccessDate,
                let lastEstimatedExpiration = estimatedExpirationDate else {
                return
            }
            let originalExpiration: StorageExpiration = .seconds(lastEstimatedExpiration.timeIntervalSince(lastAccessData))
            let attributes: [FileAttributeKey : Any] = [
                .creationDate: Date().filterAttributeDate,
                .modificationDate: originalExpiration.estimatedExpirationSinceNow.filterAttributeDate
            ]
            
            try? fileManager.setAttributes(attributes, ofItemAtPath: url.path)
        }
    }
}
