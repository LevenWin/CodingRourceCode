//
//  SessionDelegate.swift
//  KingFisher
//
//  Created by leven on 2020/2/26.
//  Copyright © 2020 leven. All rights reserved.
//

import Foundation

class SessionDelegate: NSObject {
    
    typealias SessoionChallengeFunc = (
        URLSession,
        URLAuthenticationChallenge,
        (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    )
    
    typealias SessionTaskChallengeFunc = (
        URLSession,
        URLSessionTask,
        URLAuthenticationChallenge,
        (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    )
    
    private var tasks: [URL: SessionDataTask] = [:]
    private let lock = NSLock()
    
    let onValidStatusCode = Delegate<Int, Bool>()
    let onDownloadingFinished = Delegate<(URL, Result<URLResponse, KingfisherError>), Void>()
    let onDidDownloadData = Delegate<SessionDataTask, Data?>()
    let onReceiveSessionChallenge = Delegate<SessoionChallengeFunc, Void>()
    let onReceiveSessionTaskChallenge = Delegate<SessionTaskChallengeFunc, Void>()

    func add(_ dataTask: URLSessionDataTask, url: URL, callback: SessionDataTask.TaskCallback) -> DownloadTask {
        lock.lock()
        defer {
            lock.unlock()
        }
        
        let task = SessionDataTask(task: dataTask)
        task.onCallbackCancelled.delegate(on: self) { [unowned task](self, value) in
            let (token, callback) = value
            let error = KingfisherError.requestError(reason: .taskCancelled(task: task, token: token))
            task.onTaskDone.call((.failure(error), [callback]))
            
            if !task.containsCallBack {
                let dataTask = task.task
                self.remove(dataTask)
            }
        }
        let toekn = task.addCallback(callback)
        // 后续在URLSessionDelegate的方法里根据url获取到相应的task，并进行回调
        tasks[url] = task
        return DownloadTask(sessionTask: task, cancelToken: toekn)
    }
    
    func append(
        _ task: SessionDataTask,
        url: URL,
        callback: SessionDataTask.TaskCallback
    ) -> DownloadTask {
        let token = task.addCallback(callback)
        return DownloadTask(sessionTask: task, cancelToken: token)
    }
    
    private func remove(_ task: URLSessionTask) {
        guard let url = task.originalRequest?.url else { return }
        lock.lock()
        defer { lock.unlock() }
        tasks[url] = nil
    }
    
    private func task(for task: URLSessionTask) -> SessionDataTask? {
        guard let url = task.originalRequest?.url else { return nil }
        lock.lock()
        defer { lock.unlock() }
        guard let sessionTask = tasks[url] else { return nil }
        guard sessionTask.task.taskIdentifier == task.taskIdentifier else { return nil }
        
        return sessionTask
    }
    
    func task(for url: URL) -> SessionDataTask? {
        lock.lock()
        defer { lock.unlock() }
        return tasks[url]
    }
    func cancelAll() {
        lock.lock()
        let taskValues = tasks.values
        lock.unlock()
        for task in taskValues {
            task.forceCancel()
        }
    }
    
    func cancel(url: URL) {
        lock.lock()
        let task = tasks[url]
        lock.unlock()
        task?.forceCancel()
    }
}

extension SessionDelegate: URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceived response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    )
    {
        guard let httpResponse = response as? HTTPURLResponse else {
            let error = KingfisherError.responseError(reason: .invalidURLResponse(response: response))
            onCompleted(task: dataTask, result: .failure(error))
            completionHandler(.cancel)
            return
        }
        
        let httpStatusCode = httpResponse.statusCode
        guard onValidStatusCode.call(httpStatusCode) == true else {
            let error = KingfisherError.responseError(reason: .invalidHTTPStatusCode(response: httpResponse))
            onCompleted(task: dataTask, result: .failure(error))
            completionHandler(.cancel)
            return
        }
        completionHandler(.allow)
    }
    
    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive data: Data
    )
    {
        guard let task = self.task(for: dataTask) else { return }
        
        task.didReceivedData(data)
        task.callbacks.forEach { callback in
            callback.options.onDataReceived?.forEach { sideEffect in
                sideEffect.onDataReceived(session, task: task, data: data)
                
            }
        }
    }
    
    func urlSession(
        _ session: URLSession,
        task: URLSessionDataTask,
        didCompleteWithError error: Error?
    ) {
        guard let sessionTask = self.task(for: task) else { return }
        if let url = task.originalRequest?.url {
            let result: Result<URLResponse, KingfisherError>
            if let error = error {
                result = .failure(KingfisherError.responseError(reason: .URLSessionError(error: error)))
            } else if let response = task.response {
                result = .success(response)
            } else {
                result = .failure(KingfisherError.responseError(reason: .noURLResponse(task: sessionTask)))
            }
            onDownloadingFinished.call((url, result))
        }
        
        let result: Result<(Data, URLResponse?), KingfisherError>
        if let error = error {
            result = .failure(KingfisherError.responseError(reason: .URLSessionError(error: error)))
        } else {
            if let data = onDidDownloadData.call(sessionTask), let finalData = data {
                result = .success((finalData, task.response))
            } else {
                result = .failure(KingfisherError.responseError(reason: .dataModifyingFailed(task: sessionTask)))
            }
        }
        onCompleted(task: task, result: result)
    }
    
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        onReceiveSessionTaskChallenge.call((session, task, challenge, completionHandler))
    }
    
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard let sessionDataTask = self.task(for: task), let redirecHandler = Array(sessionDataTask.callbacks).last?.options.redirectHandler else {
            completionHandler(request)
            return
        }
        redirecHandler.handleHTTPRedirection(for: sessionDataTask, reponse: response, newRequest: request, completionHandler: completionHandler)
    }
    
    
    
    
    private func onCompleted(task: URLSessionTask, result:Result<(Data, URLResponse?), KingfisherError>) {
        guard let sessionTask = self.task(for: task) else { return }
        remove(task)
        sessionTask.onTaskDone.call((result, sessionTask.callbacks))
    }
}
