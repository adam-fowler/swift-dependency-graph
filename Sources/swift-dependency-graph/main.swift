import Foundation
import NIO
import AsyncHTTPClient

enum SwiftDependencyError : Error {
    case noPackageBody
}

let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
let client = HTTPClient(eventLoopGroupProvider: .shared(eventLoopGroup))
let url = "https://github.com/daveverwer/SwiftPMLibrary/blob/master/packages.json"

let future = client.get(url: url, deadline: .now() + .seconds(5)).flatMapThrowing { (response)->[String:Any] in
    guard let body = response.body else {throw SwiftDependencyError.noPackageBody}
    guard let bytes = body.getBytes(at: 0, length: body.capacity-1) else {throw SwiftDependencyError.noPackageBody}
    
    let data = Data(bytes)
    let dictionary = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] ?? [:]
    return dictionary
}

let result = try future.wait()
print(result)
