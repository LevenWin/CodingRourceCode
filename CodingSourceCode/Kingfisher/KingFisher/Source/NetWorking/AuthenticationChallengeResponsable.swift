//
//  AuthenticationChallengeResponsable.swift
//  KingFisher
//
//  Created by leven on 2020/2/27.
//  Copyright © 2020 leven. All rights reserved.
//

import Foundation

public protocol AuthenticationChallengeResponsable: AnyObject {
    
    func downloader(
        _ downloader: ImageDownloader,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    )
    
    func downloader(
        _ downloader: ImageDownloader,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    )
}


extension AuthenticationChallengeResponsable {
    public func downloader(
        _ downloader: ImageDownloader,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    )
    {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            if let trustedHosts = downloader.trustHosts, trustedHosts.contains(challenge.protectionSpace.host) {
                let credential = URLCredential(trust: challenge.protectionSpace.serverTrust!)
                completionHandler(.useCredential, credential)
                return
            }
        }
        completionHandler(.performDefaultHandling, nil)
    }
    public   
    func downloader(
        _ downloader: ImageDownloader,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    )
    {
        completionHandler(.performDefaultHandling, nil)
    }
    
    
    
}
