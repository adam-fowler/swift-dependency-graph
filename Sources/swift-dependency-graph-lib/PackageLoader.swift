//
//  PackageLoader.swift
//  AsyncHTTPClient
//
//  Created by Adam Fowler on 18/08/2019.
//

import Foundation
import NIO
import Basic
import PackageGraph
import PackageLoading
import PackageModel
import Workspace

class PackageLoader {
    
    let manifestLoader : PackageManifestLoader
    let eventLoopGroup : EventLoopGroup
    let httpLoader : HTTPLoader
    let addPackage : (String, Package)->()
    var packageNames : [String] = []

    init(addPackage: @escaping (String, Package)->()) throws {
        self.manifestLoader = try PackageManifestLoader()
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        self.httpLoader = HTTPLoader(eventLoopGroup: eventLoopGroup)
        self.addPackage = addPackage
    }
    
    func load(url: String, packages: Packages) throws {
        if url.hasPrefix("http") {
            // get package names
            packageNames = try httpLoader.getBody(url: url)
                .flatMapThrowing { (buffer) throws -> [String] in
                    let data = Data(buffer)
                    let names = try JSONSerialization.jsonObject(with: data, options: []) as? [String] ?? []
                    return names
                }.wait()
        } else {
            let data = try Data(contentsOf: URL(fileURLWithPath: url))
            packageNames = try JSONSerialization.jsonObject(with: data, options: []) as? [String] ?? []
        }
        // add packages to Package array
        while(packageNames.count > 0) {
            let added = addPackageIndex(index: 0)
            _ = try added.wait()
            // create new list of packages containing packages that haven't been loaded
            packageNames = packages.packages.compactMap {return !$0.value.readPackageSwift ? $0.key : nil}
        }
    }
    
    func addPackage(url: String) -> Future<Void> {
        guard let packageUrl = Packages.getPackageUrl(url: url) else { return eventLoopGroup.next().makeSucceededFuture(Void())}
        
        return httpLoader.getBody(url: packageUrl)
            .flatMap { [unowned self] buffer in
                self.eventLoopGroup.next().submit {
                    return try self.manifestLoader.load(buffer, url: url)
                    }
                    .flatMap { buffer in
                        self.eventLoopGroup.next().submit {
                            print("Adding \(url)")
                            self.addPackage(url, Package(dependencies: buffer))
                        }
                }
        }
    }
    
    func addPackageIndex(index: Int) -> Future<Void> {
        if index >= packageNames.count {
            return self.eventLoopGroup.next().makeSucceededFuture(Void())
        }
        return addPackage(url: packageNames[index]).flatMap { return self.addPackageIndex(index: index+1) }
    }
}

public class PackageManifestLoader {
    public init() throws {
        self.userToolchain = try UserToolchain(destination: Destination.hostDestination(AbsolutePath("/Library/Developer/CommandLineTools/usr/bin/")))
    }
    
    public func load(_ buffer: [UInt8], url: String) throws -> [String] {
        let diagnostics = DiagnosticsEngine()
        let fs = InMemoryFileSystem()
        try fs.writeFileContents(AbsolutePath("/Package.swift"), bytes: ByteString(buffer))
        
        print("Loading manifest from \(url)")
        
        do {
            let manifest = try ManifestLoader(manifestResources: userToolchain.manifestResources).load(packagePath:AbsolutePath("/"), baseURL: url, version: nil, manifestVersion: .v5, fileSystem: fs, diagnostics: diagnostics)
            let dependencies = manifest.dependencies.map {$0.url}
            return dependencies
        } catch {
            print(error.localizedDescription)
        }
        return []
    }
    
    let userToolchain : UserToolchain
}


