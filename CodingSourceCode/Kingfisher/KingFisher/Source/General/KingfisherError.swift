//
//  KingfisherError.swift
//  KingFisher
//
//  Created by leven on 2020/2/26.
//  Copyright © 2020 leven. All rights reserved.
//

import Foundation
extension Never {}

public enum KingfisherError: Error {
    
    public enum RequestErrorReason {
        case emptyRequest
        
        case invalidURL(request: URLRequest)
        
        case taskCancelled(task: SessionDataTask, token: SessionDataTask.CancelToken)
    }
    
    public enum ResponseErrorReason {
        case invalidURLResponse(response: URLResponse)
        
        case invalidHTTPStatusCode(response: HTTPURLResponse)
        
        case URLSessionError(error: Error)
        
        case dataModifyingFailed(task: SessionDataTask)
        
        case noURLResponse(task: SessionDataTask)
    }
    public enum CacheErrorReason {
        
        case fileEnumeratorOrCreationFailed(url: URL)
        
        case invalidFileEnumeratorORContent(url: URL)
        
        case invalidURLResource(error: Error, key: String, url: URL)
        
        case cannotLoadDataFromDisk(url: URL, error: Error)
        
        case cannotCreateDirectory(path: String, error: Error)
        
        case imageNorExiting(key: String)
        
        case cannotConvertToData(object: Any, error: Error)
        
        case cannotSerializeImage(image: Image?, original: Data?, serializer: CacheSerializer)
    }
    
    public enum ProcessorErrorReason {
        case processingFailed(processor: ImageProcessor, item: ImageProcessItem)
    }
    
    public enum ImageSettingErrorReason {
        case emptySource
        
        case notCurrentSourceTask(result: AnyObject?, error: Error?)
        
        case dataProviderError(provider: ImageDataProvider, error: Error)
    }
    
    case requestError(reason: RequestErrorReason)
    
    case responseError(reason: ResponseErrorReason)
    
    case cacheError(reason: CacheErrorReason)
    
    case processError(reason: ProcessorErrorReason)
    
    case imageSettingError(reason: ImageSettingErrorReason)
    
    public var isTaskCancelled: Bool {
        if case .requestError(reason: .taskCancelled) = self {
            return true
        }
        return false
    }
    
    public func isInvalidResponseStatusCode(_ code: Int) -> Bool {
//        if case .responseError(reason: .invalidHTTPStatusCode(let response)) == self {
//            return response.statusCode == code
//        }
        return false
    }
    
    public var isInvalidResponseStatusCode: Bool {
        if case .responseError(reason: .invalidHTTPStatusCode) = self {
            return true
        }
        return false
    }
    
    public var isNotCurrentTask: Bool {
//        if case .imageSettingError(reason: .notCurrentSrouceTask(_, _, _)) == self {
//            return true
//        }
        return false
    }
}

extension KingfisherError: LocalizedError {
//    public var errorDescription: String? {
//        switch self {
//        case .requestError(let reason):
//            return reason.errorDescription
//        default:
//            <#code#>
//        }
//    }
}
