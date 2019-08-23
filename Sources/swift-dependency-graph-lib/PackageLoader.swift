//
//  PackageLoader.swift
//  AsyncHTTPClient
//
//  Created by Adam Fowler on 18/08/2019.
//

import Foundation
import NIO
import Basic
import Workspace
import PackageLoading
import PackageModel

enum PackageLoaderError : Error {
    case invalidManifest
    case looping
}


class PackageLoader {
    
    let manifestLoader : PackageManifestLoader
    let eventLoopGroup : EventLoopGroup
    let httpLoader : HTTPLoader
    let onAdd : (String, Package)->()
    let onError : (String, Error)->()

    init(onAdd: @escaping (String, Package)->(), onError: @escaping (String, Error)->() = {_,_ in }) throws {
        self.manifestLoader = try PackageManifestLoader()
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        self.httpLoader = HTTPLoader(eventLoopGroup: eventLoopGroup)
        self.onAdd = onAdd
        self.onError = onError
    }
    
    func load(url: String, packages: Packages) throws -> [String] {
        if url.hasPrefix("http") {
            // get package names
            return try httpLoader.getBody(url: url)
                .flatMapThrowing { (buffer) throws -> [String] in
                    let data = Data(buffer)
                    var names = try JSONSerialization.jsonObject(with: data, options: []) as? [String] ?? []
                    // append self to the list
                    names.append("https://github.com/adam-fowler/swift-dependency-graph.git")
                    return names
                }.wait()
        } else {
            let data = try Data(contentsOf: URL(fileURLWithPath: url))
            return try JSONSerialization.jsonObject(with: data, options: []) as? [String] ?? []
        }
    }
    
    func loadPackages(_ packages: [String]) -> Future<Void> {
        func addStartingFrom(index: Int) -> Future<Void> {
            if index >= packages.count {
                return self.eventLoopGroup.next().makeSucceededFuture(Void())
            }
            let name = packages[index]
            return addPackage(url: name)
                .flatMapError { (error)->Future<Void> in
                    self.onError(name, error)
                    return self.eventLoopGroup.next().makeSucceededFuture(Void())
                }
                .flatMap {
                    return addStartingFrom(index: index+1)
            }
        }
        return addStartingFrom(index: 0)
    }

    func addPackage(url: String) -> Future<Void> {
        guard let packageUrl = Packages.getPackageUrl(url: url) else { return eventLoopGroup.next().makeSucceededFuture(Void())}
        guard let packageV5Url = Packages.getPackageUrl(url: url, version: "5") else { return eventLoopGroup.next().makeSucceededFuture(Void())}
        var packageUrlToLoad = packageV5Url
        
        return httpLoader.getBody(url: packageV5Url)
            .flatMapError { (error)->Future<[UInt8]> in
                packageUrlToLoad = packageUrl
                return self.httpLoader.getBody(url: packageUrl)
            }
            .flatMap { buffer in
                self.eventLoopGroup.next().submit {
                    return try self.manifestLoader.load(buffer, url: packageUrlToLoad)
                    }
                    .flatMap { buffer in
                        self.eventLoopGroup.next().submit {
                            print("Adding \(url)")
                            self.onAdd(url, Package(dependencies: buffer))
                        }
                }
        }
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
        
        let manifest : Manifest
        do {
            manifest = try ManifestLoader(manifestResources: userToolchain.manifestResources).load(packagePath:AbsolutePath("/"), baseURL: url, version: nil, manifestVersion: .v5, fileSystem: fs, diagnostics: diagnostics)
        } catch {
            do {
                manifest = try ManifestLoader(manifestResources: userToolchain.manifestResources).load(packagePath:AbsolutePath("/"), baseURL: url, version: nil, manifestVersion: .v4_2, fileSystem: fs, diagnostics: diagnostics)
            } catch {
                do {
                    manifest = try ManifestLoader(manifestResources: userToolchain.manifestResources).load(packagePath:AbsolutePath("/"), baseURL: url, version: nil, manifestVersion: .v4, fileSystem: fs, diagnostics: diagnostics)
                } catch PackageLoading.ManifestParseError.invalidManifestFormat {
                    throw PackageLoaderError.invalidManifest
                }
            }
        }
        let dependencies = manifest.dependencies.map {$0.url}
        return dependencies
    }
    
    let userToolchain : UserToolchain
}


