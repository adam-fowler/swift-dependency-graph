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
        case noPackageBody
    }
    
    let eventLoopGroup : EventLoopGroup
    let client : HTTPClient

    public init(eventLoopGroup : EventLoopGroup) {
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        self.client = HTTPClient(eventLoopGroupProvider: .shared(self.eventLoopGroup))
    }
    
    public func get(url: String) -> EventLoopFuture<HTTPClient.Response> {
        return client.get(url: url, deadline: .now() + .seconds(5))
    }
    
    public func getBody(url: String) -> EventLoopFuture<[UInt8]> {
        return get(url: url).flatMapThrowing { (response)->[UInt8] in
            guard let body = response.body else {throw HTTPError.noPackageBody}
            guard let bytes = body.getBytes(at: 0, length: body.readableBytes) else {throw HTTPError.noPackageBody}
            return bytes
        }
    }
}
