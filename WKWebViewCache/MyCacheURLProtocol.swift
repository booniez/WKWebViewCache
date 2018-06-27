//
//  MyCacheURLProtocol.swift
//  WKWebViewCache
//
//  Created by monstar1 on 2018/6/25.
//  Copyright © 2018年 monstar1. All rights reserved.
//

import UIKit

class MyCacheURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) ->Bool {
        if URLProtocol.property(forKey: MyCacheURLProtocol.PropertyKey.tagKey, in: request) != nil {
            return false
        }
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        func sendRequest() {
            checkRedirectOrSendRequest()
        }
        
        // 有缓存则使用缓存，无缓存则发送请求
        self.getResponse(success: { (cacheResponse) in
            self.client?.urlProtocol(self, didReceive: cacheResponse.response, cacheStoragePolicy: .notAllowed)
            self.client?.urlProtocol(self, didLoad: cacheResponse.data)
            self.client?.urlProtocolDidFinishLoading(self)
        }, failure:{
            sendRequest()
        })
    }
    
    override func stopLoading() {
        self.dataTask?.cancel()
        self.dataTask       = nil
        self.receivedData   = nil
        self.urlResponse    = nil
    }
    
    override class func requestIsCacheEquivalent(_ a: URLRequest, to b: URLRequest) -> Bool {
        return super.requestIsCacheEquivalent(a, to: b)
    }
    
    // MARK: - 私有方法
    // 1.查看是否有重定向
    // 1.1 有则映射重定向网站的缓存
    // 1.2 无则继续查看原请求是否有缓存
    // 2.都无缓存，则发送请求
    fileprivate func checkRedirectOrSendRequest() {
        // 未获取到缓存---查看是否有重定向，有则加载重定向
        SQLiteManager.shared.fetchOrDeleteRedirectInfo(url: request.url?.absoluteString, success: { (storedRequest, storedResponse) in
            guard let redirectRequest = (storedRequest as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {return}
            URLProtocol.removeProperty(forKey: MyCacheURLProtocol.PropertyKey.tagKey, in: redirectRequest)
            self.client?.urlProtocol(self, wasRedirectedTo: redirectRequest as URLRequest, redirectResponse: storedResponse)
        }) {
            guard let newRequest = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {return}
            URLProtocol.setProperty("blablabla", forKey: MyCacheURLProtocol.PropertyKey.tagKey, in: newRequest)
            let sessionConfig = URLSessionConfiguration.default
            let urlSession = URLSession(configuration: sessionConfig, delegate: self, delegateQueue: nil)
            self.dataTask = urlSession.dataTask(with: newRequest as URLRequest)
            self.dataTask?.resume()
        }
    }
    
    /// 将网页数据缓存入数据库
    fileprivate func saveResponse(_ response:URLResponse,_ data:Data) {
        if let url = self.request.url?.absoluteString {
            SQLiteManager.shared.searchAndUpdateOrInsertCacheInfo(url: url, response, data)
        }
    }
    
    /// 获取网页缓存
    fileprivate func getResponse(success:(CachedURLResponse)->Void,failure:()->Void) {
        if let url = self.request.url?.absoluteString {
            SQLiteManager.shared.fetchOrDeleteCacheInfo(url: url, success: success, failure: failure)
        }
    }
    
    // MARK: - 私有变量
    fileprivate var dataTask: URLSessionDataTask?
    fileprivate var urlResponse: URLResponse?
    fileprivate var receivedData: NSMutableData?
}

extension MyCacheURLProtocol {
    struct PropertyKey{
        static var tagKey = "MyURLProtocolTagKey"
    }
}

extension MyCacheURLProtocol:URLSessionTaskDelegate,URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        self.urlResponse = response
        self.receivedData = NSMutableData()
        completionHandler(.allow)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        guard let url = self.request.url?.absoluteString else {return}
        // 插入重定向记录
        SQLiteManager.shared.searchAndUpdateOrInsertRedirectInfo(url: url, response: response, request: request)
        // 请求重定向后的地址
        guard let redirectRequest = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {return}
        URLProtocol.removeProperty(forKey: MyCacheURLProtocol.PropertyKey.tagKey, in: redirectRequest)
        self.client?.urlProtocol(self, wasRedirectedTo: redirectRequest as URLRequest, redirectResponse: response)
        self.dataTask?.cancel()
        self.client?.urlProtocol(self, didFailWithError: NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil))
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        self.client?.urlProtocol(self, didLoad: data)
        self.receivedData?.append(data)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        print("开始缓存")
        if error != nil {
            self.client?.urlProtocol(self, didFailWithError: error!)
        } else {
            if self.urlResponse != nil && self.receivedData != nil {
                self.saveResponse(self.urlResponse!, self.receivedData?.copy() as! Data)
            }
            self.client?.urlProtocolDidFinishLoading(self)
        }
    }
}

/// 字符串MD5
extension String {
    func md5() -> String{
        let cStr = self.cString(using: .utf8);
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 16)
        CC_MD5(cStr!,(CC_LONG)(strlen(cStr!)), buffer)
        let md5String = NSMutableString();
        for i in 0 ..< 16{
            md5String.appendFormat("%02x", buffer[i])
        }
        free(buffer)
        return md5String as String
    }
}

/// 归档路径
let cachePath = NSSearchPathForDirectoriesInDomains(.documentDirectory,.userDomainMask, true).first! as NSString
