//
//  http.swift
//  AsyncHTTPClient
//
//  Created by Adam Fowler on 18/08/2019.
//

import Foundation
import NIO
import AsyncHTTPClient


public class HTTPLoader {
    enum HTTPError : Error {
        case noPackageBody(String)
        case failedToLoad(String)
        case moved(String?)
    }
    
    let eventLoopGroup : EventLoopGroup
    let client : HTTPClient

    public init(eventLoopGroup : EventLoopGroup) {
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        self.client = HTTPClient(eventLoopGroupProvider: .shared(self.eventLoopGroup))
    }
    
    func syncShutdown() throws {
        try client.syncShutdown()
    }
    
    public func get(url: String) -> EventLoopFuture<HTTPClient.Response> {
        return client.get(url: url, deadline: .now() + .seconds(5)).flatMapThrowing { (response)->HTTPClient.Response in
            guard response.status != .movedPermanently else {throw HTTPError.moved(response.headers["Location"].first)}
            guard response.status != .found else {throw HTTPError.moved(response.headers["Location"].first)}
            guard response.status == .ok else {throw HTTPError.failedToLoad(url)}
            return response
            }
            .flatMapError { (error)->EventLoopFuture<HTTPClient.Response> in
                switch error {
                case HTTPError.moved(let newUrl):
                    if let url = newUrl {
                        return self.get(url: url)
                    }
                default:
                    break
                }
                return self.eventLoopGroup.next().makeFailedFuture(error)
        }
    }
    
    public func getBody(url: String) -> EventLoopFuture<[UInt8]> {
        return get(url: url).flatMapThrowing { (response)->[UInt8] in
            guard let body = response.body else {throw HTTPError.noPackageBody(url)}
            guard let bytes = body.getBytes(at: 0, length: body.readableBytes) else {throw HTTPError.noPackageBody(url)}
            return bytes
        }
    }
}
