//
//  ImageDownloader.swift
//  KingFisher
//
//  Created by leven on 2020/2/26.
//  Copyright © 2020 leven. All rights reserved.
//

import Foundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif

public struct ImageLoadingResult {
    public let image: Image
    public let url: URL?
    public let originalData: Data
}

public struct DownloadTask {
    public let sessionTask: SessionDataTask
    
    public let cancelToken: SessionDataTask.CancelToken
    
    public func cancel() {
        sessionTask.cacel(token: cancelToken)
    }
}

extension DownloadTask {
    enum WrappedTask {
        case download(DownloadTask)
        case dataProviding
        
        func cancel() {
            switch self {
            case .download(let task):
                task.cancel()
            case .dataProviding:
                break
            }
        }
    }
}

open class ImageDownloader {
//    public static let `default` = ImageDownloader(name)
    
    open var downloadTimeout: TimeInterval = 15.0
    
    open var trustHosts: Set<String>?
    
    open var requestsUserPipelining = false
    
    open weak var delegate: ImageDownloaderDelegate?
    
    private let sessionDelegate: SessionDelegate

    open var sessionConfiguration = URLSessionConfiguration.ephemeral {
        didSet {
            session.invalidateAndCancel()
            session = URLSession(configuration: sessionConfiguration, delegate: sessionDelegate, delegateQueue: nil)
        }
    }
    
    open weak var authenticationChallengeResponder: AuthenticationChallengeResponsable?
    
    private let name: String
    private var session: URLSession
    
    public init(name: String)
    {
        if name.isEmpty {
            fatalError("[Kingfisher] You should specify a name for the downloader." + "A downloader with empty name is not permitted.")
        }
        self.name = name
        sessionDelegate = SessionDelegate()
        session = URLSession(
            configuration: sessionConfiguration, delegate: sessionDelegate, delegateQueue: nil
        )
        
        authenticationChallengeResponder  = self as! AuthenticationChallengeResponsable
    }
    
    deinit {
        session.invalidateAndCancel()
    }
    
    private func setupSessionHandler() {
        sessionDelegate.onReceiveSessionChallenge.delegate(on: self) { (self, invoke) in
            self.authenticationChallengeResponder?.downloader(self, didReceive: invoke.1, completionHandler: invoke.2)
        }
        sessionDelegate.onReceiveSessionTaskChallenge.delegate(on: self) { (self, invoke) in
            self.authenticationChallengeResponder?.downloader(self, task: invoke.1, didReceive: invoke.2, completionHandler: invoke.3)
        }
        sessionDelegate.onValidStatusCode.delegate(on: self) { (self, code) -> Bool in
            return (self.delegate ?? self).isValidStatusCode(code, for: self)
        }
        
        sessionDelegate.onDidDownloadData.delegate(on: self) { (self, task) -> Data? in
            guard let url = task.task.originalRequest?.url else {
                return task.mutableData
            }
            return (self.delegate ?? self).imageDownloader(self, didDownload: task.mutableData, for: url)
        }
        
        sessionDelegate.onDownloadingFinished.delegate(on: self) { (self, value) in
              let (url, result) = value
              do {
                  let value = try result.get()
                  self.delegate?.imageDownloader(self, didFinishDownloadingImageForURL: url, with: value, error: nil)
              } catch {
                  self.delegate?.imageDownloader(self, didFinishDownloadingImageForURL: url, with: nil, error: error)
              }
          }
    }
    
    @discardableResult
    open func downloadImage(
        with url: URL,
        options: KingfisherParsedOptionsInfo,
        completionHandler: ((Result<ImageLoadingResult, KingfisherError>) -> Void)? = nil
    ) -> DownloadTask? {
        
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: downloadTimeout)
        request.httpShouldUsePipelining = requestsUserPipelining
        if let requestModifier = options.requestModifier {
            guard let r = requestModifier.modified(for: request) else {
                options.callbackQueue.execute {
                    completionHandler?(.failure(KingfisherError.requestError(reason: .emptyRequest)))
                }
                return nil
            }
            request = r
        }
            guard let url = request.url, !url.absoluteString.isEmpty else {
                options.callbackQueue.execute {
                    completionHandler?(.failure(KingfisherError.requestError(reason: .invalidURL(request: request))))
                }
                return nil
            }
            
            
            let onCompleted = completionHandler.map {
                block -> Delegate<Result<ImageLoadingResult, KingfisherError>, Void> in
                let delegate = Delegate<Result<ImageLoadingResult, KingfisherError>, Void>()
                delegate.delegate(on: self) { (self, callback) in
                    block(callback)
                }
                return delegate
                        
            }
            
            let callbak = SessionDataTask.TaskCallback(
                onCompleted: onCompleted, options: options
            )
            
            let downloadTask: DownloadTask
            if let existingTask = sessionDelegate.task(for: url) {
                downloadTask = sessionDelegate.append(existingTask, url: url, callback: callbak)
            } else {
                let sessionDataTask = session.dataTask(with: request)
                sessionDataTask.priority = options.downloadPriority
                downloadTask = sessionDelegate.add(sessionDataTask, url: url, callback: callbak)
            }
            
            let sessionTask = downloadTask.sessionTask
            if !sessionTask.started {
                sessionTask.onTaskDone.delegate(on: self) { (self, done) in
                    let (result, callbacks) = done

                    do {
                        let value = try result.get()
                        self.delegate?.imageDownloader(self, didFinishDownloadingImageForURL: url, with: value.1, error: nil)
                    } catch {
                        self.delegate?.imageDownloader(self, didFinishDownloadingImageForURL: url, with: nil, error: error)
                    }
                    
                    switch result {
                        
                    case .success(let (data, response)):
                        let processor = ImageDataProcessor(data: data, callbacks: callbacks, processingQueue: options.processingQueue)
                        processor.onImageProcessed.delegate(on: self) { (self, result) in
                            let (result, callback) = result
                            if let image = try? result.get() {
                                self.delegate?.imageDownloader(self, didDownload: image, for: url, with: response)
                            }
                            let imageResult = result.map { ImageLoadingResult(image: $0, url: url, originalData: data)}
                            let queue = callback.options.callbackQueue
                            queue.execute { callback.onCompleted?.call(imageResult) }
                        }
                        processor.process()
                        
                    case .failure(let error):
                        callbacks.forEach { callback in
                            let queue = callback.options.callbackQueue
                            queue.execute {
                                callback.onCompleted?.call(.failure(error))
                            }
                            
                        }
                    }

                }
                
                delegate?.imageDownloader(self, willDownloadImageForURL: url, with: request)
                sessionTask.resume()
            }
            return downloadTask
        }
}
    
extension ImageDownloader: AuthenticationChallengeResponsable {
    
    
}


extension ImageDownloader: ImageDownloaderDelegate {

}
