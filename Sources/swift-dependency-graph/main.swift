import Foundation
import NIO
import swift_dependency_graph_lib

typealias Future = EventLoopFuture

let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 4)
let httpLoader = HTTPLoader(eventLoopGroup: eventLoopGroup)
let packages = Packages()

let url = "https://raw.githubusercontent.com/daveverwer/SwiftPMLibrary/master/packages.json"
let url2 = "https://raw.githubusercontent.com/swift-aws/aws-sdk-appleos-core/master/Package.swift"

func addPackage(url: String) -> Future<Void> {

    // get Package.swift URL
    var split = url.split(separator: "/", omittingEmptySubsequences: false)
    if split[2] == "github.com" {
        split[2] = "raw.githubusercontent.com"
    }
    let last = split.count - 1
    split[last] = Packages.cleanupName(split[last])
    split.append("master/Package.swift")
    let packageUrl = split.joined(separator: "/")

    return httpLoader.getBody(url: packageUrl)
        .flatMap { buffer in
            eventLoopGroup.next().submit {
                return try PackageLoader().load(buffer, url: url)
                }
                .flatMap { buffer in
                    eventLoopGroup.next().submit {
                        print("Adding \(url)")
                        packages.add(name: url, package: Package(dependencies: buffer))
                    }
            }
    }
}

/*let future = httpLoader.getBody(url: url)
    .flatMapThrowing { (buffer) throws -> [String] in
        let packageNames = try JSONSerialization.jsonObject(with: Data(buffer), options: []) as? [String] ?? []
        return packageNames
    }
    .flatMap { (packageNames) -> Future<Bool> in
        func addPackageIndex(index: Int) -> Future<Bool> {
            if index >= packageNames.count {
                return eventLoopGroup.next().makeSucceededFuture(true)
            }
            return addPackage(url: packageNames[index]).flatMap { return addPackageIndex(index: index+1) }
        }
        
        return addPackageIndex(index: 0)
}


_ = try future.wait()
print("The End")*/

var packageNames : [String] = try httpLoader.getBody(url: url)
    .flatMapThrowing { (buffer) throws -> [String] in
        let packageNames = try JSONSerialization.jsonObject(with: Data(buffer), options: []) as? [String] ?? []
        return packageNames
}.wait()

func addPackageIndex(index: Int) -> Future<Bool> {
    if index >= packageNames.count {
        return eventLoopGroup.next().makeSucceededFuture(true)
    }
    return addPackage(url: packageNames[index]).flatMap { return addPackageIndex(index: index+1) }
}

while(packageNames.count > 0) {
    let added = addPackageIndex(index: 0)
    _ = try added.wait()
    packageNames = packages.packages.compactMap {return !$0.value.readPackageSwift ? $0.key : nil}
}

/*let future2 = addPackage(url: "https://github.com/swift-aws/aws-sdk-appleos-core.git")
do {
    try future2.wait()
    //print(result2)
} catch {
    print(error)
}*/

/*let future = HTTPLoader.instance.getBody(url: url).flatMapThrowing { (data)->[String] in
    let dictionary = try JSONSerialization.jsonObject(with: Data(data), options: []) as? [String] ?? []
    return dictionary
}

let result = try future.wait()
print(result)*/
