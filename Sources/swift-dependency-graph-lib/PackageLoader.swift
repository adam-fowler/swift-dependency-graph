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
import SPMUtility

enum PackageLoaderError : Error {
    case invalidUrl
    case invalidManifest
    case looping
    case gitVersionLoadingFailed(errorOutput: String)
    case noVersions
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
    
    /// load package names from json
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
    
    /// load packages from array of package names
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

    /// add a package, works out default branch and calls add package with branch name, then calls onAdd callback
    func addPackage(url: String) -> Future<Void> {
        // get package.swift from default branch
        return self.getDefaultBranch(url: url).flatMap { (branch)->Future<[String]> in
            return self.addPackage(url: url, version: branch)
            }
            .map { buffer in
                print("Adding \(url)")
                self.onAdd(url, Package(dependencies: buffer))
        }
    }
    
    func addPackage(url: String, version: String?) -> Future<[String]>{

        let repositoryUrl : String
        if let url = PackageLoader.getRawRepositoryUrl(url: url, version: version) {
            repositoryUrl = url
        } else {
            return self.eventLoopGroup.next().makeFailedFuture(PackageLoaderError.invalidUrl)
        }
        // Order of loading is
        // - Package@swift-5.swift
        // - Package.swift
        // - Package@swift-4.2.swift
        // - Package@swift-4.swift
        var errorPassedDown : Error? = nil
        var packageUrlToLoad = repositoryUrl + "/Package@swift-5.swift"
        return self.httpLoader.getBody(url: packageUrlToLoad)
            
            .flatMapError { (error)->Future<[UInt8]> in
                packageUrlToLoad = repositoryUrl + "/Package.swift"
                return self.httpLoader.getBody(url: packageUrlToLoad)
            }
            .flatMap { (buffer)->Future<[String]> in
                return self.eventLoopGroup.next().submit {
                    return try self.manifestLoader.load(buffer, url: packageUrlToLoad)
                }
            }
            .flatMapError { (error)->Future<[String]> in
                errorPassedDown = error
                packageUrlToLoad = repositoryUrl + "/Package@swift-4.2.swift"
                return self.httpLoader.getBody(url: packageUrlToLoad)
                    .flatMap { buffer in
                        return self.eventLoopGroup.next().submit {
                            return try self.manifestLoader.load(buffer, url: packageUrlToLoad, versions: [.v4, .v4_2])
                        }
                }
            }
            .flatMapError { (error)->Future<[String]> in
                packageUrlToLoad = repositoryUrl + "/Package@swift-4.swift"
                return self.httpLoader.getBody(url: packageUrlToLoad)
                    .flatMap { buffer in
                        return self.eventLoopGroup.next().submit {
                            return try self.manifestLoader.load(buffer, url: packageUrlToLoad, versions: [.v4])
                        }
                }
            }
            .flatMapErrorThrowing { error in
                throw errorPassedDown ?? error
        }
        
    }

    func getDefaultBranch(url: String) -> Future<String> {
        return eventLoopGroup.next().submit { ()->String in
            guard let lsRemoteOutput = try? Process.checkNonZeroExit(
                args: Git.tool, "ls-remote", "--symref", url, "HEAD", environment: Git.environment).spm_chomp() else {return "master"}
            // split into tokens separated by space. The second token is the branch ref.
            let branchRefTokens = lsRemoteOutput.components(separatedBy: CharacterSet.whitespacesAndNewlines)
            var branch : Substring? = nil
            if branchRefTokens.count > 1 {
                // split branch ref by '/'. Last element is branch name
                branch = branchRefTokens[1].split(separator: "/").last
            }
            if let branch = branch {
                return String(branch)
            }
            return "master"
        }
    }
    
    func getLatestVersion(url: String) -> Future<String?> {
        let regularExpressionXXX = try! NSRegularExpression(pattern: "[0-9]+\\.[0-9]+\\.[0-9]+$", options: [])
        let regularExpressionXX = try! NSRegularExpression(pattern: "[0-9]+\\.[0-9]+$", options: [])
        // Look into getting versions
        // git ls-remote --tags <repository>.
        return eventLoopGroup.next().submit { ()->String? in
            guard let lsRemoteOutput = try? Process.checkNonZeroExit(
                args: Git.tool, "ls-remote", "--tags", url, environment: Git.environment).spm_chomp() else {return nil}
            let tags = lsRemoteOutput.split(separator: "\n").compactMap { $0.split(separator:"/").last }
            let versions = tags
                .map {String($0)}
                .compactMap { (versionString)->(v:Version, s:String)? in
                    /// if of form major.minor.patch
                    let cleanVersionString : String
                    let firstMatchRangeXXX = regularExpressionXXX.rangeOfFirstMatch(in: versionString, options: [], range: NSMakeRange(0, versionString.count))
                    if let range = Range(firstMatchRangeXXX, in: versionString) {
                        cleanVersionString = String(versionString[range])
                    } else {
                        /// if of form major.minor
                        let firstMatchRangeXX = regularExpressionXX.rangeOfFirstMatch(in: versionString, options: [], range: NSMakeRange(0, versionString.count))
                        if let range = Range(firstMatchRangeXX, in: versionString) {
                            cleanVersionString = String(versionString[range])+".0"
                        } else {
                            return nil
                        }
                    }
                    if let version = Version(string: cleanVersionString) {
                        return (version, versionString)
                    }
                    return nil
                }
                .sorted {$0.v < $1.v}
                .map {$0.s}

            return versions.last
        }
    }
    
    /// get URL from github repository name
    static func getRawRepositoryUrl(url: String, version: String? = nil) -> String? {
        let url = Packages.cleanupName(url)
        
        // get Package.swift URL
        var split = url.split(separator: "/", omittingEmptySubsequences: false)
        if split.last == "" {
            split = split.dropLast()
        }
        
        if split.count > 2 && split[2] == "github.com" {
            split[2] = "raw.githubusercontent.com"
        } else if split.count > 2 && split[2] == "gitlab.com" {
            split.append("raw")
        }
        
        if let version = version {
            split.append("\(version)")
        } else {
            split.append("master")
        }
        
        return split.joined(separator: "/")
    }
    
    /// return if this is a valid repository name
    static func isValidUrl(url: String) -> Bool {
        let split = url.split(separator: "/", omittingEmptySubsequences: false)
        if split[0].hasPrefix("git@github.com") && split.count == 2
            || split.count > 4 && split[2] == "github.com"
            || split.count > 4 && split[2] == "gitlab.com" {
            return true
        }
        return false
    }
}

public class PackageManifestLoader {
    public init() throws {
        self.userToolchain = try UserToolchain(destination: Destination.hostDestination(AbsolutePath("/Library/Developer/CommandLineTools/usr/bin/")))
    }
    
    public func load(_ buffer: [UInt8], url: String, versions: [ManifestVersion] = [.v4,.v4_2,.v5]) throws -> [String] {
        var versions = versions
        let diagnostics = DiagnosticsEngine()
        let fs = InMemoryFileSystem()
        try fs.writeFileContents(AbsolutePath("/Package.swift"), bytes: ByteString(buffer))
        
        print("Loading manifest from \(url)")
        
        while(true) {
            do {
                guard let version = versions.last else {throw PackageLoaderError.invalidManifest}
                let manifest = try ManifestLoader(manifestResources: userToolchain.manifestResources).load(packagePath:AbsolutePath("/"), baseURL: url, version: nil, manifestVersion: version, fileSystem: fs, diagnostics: diagnostics)
                let dependencies = manifest.dependencies.map {$0.url}
                return dependencies
            } catch PackageLoaderError.invalidManifest {
                throw PackageLoaderError.invalidManifest
            } catch {
                versions = versions.dropLast()
            }
        }
    }
    
    let userToolchain : UserToolchain
}


