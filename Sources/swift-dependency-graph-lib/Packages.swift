//
//  Packages.swift
//  AsyncHTTPClient
//
//  Created by Adam Fowler on 18/08/2019.
//

import Foundation
import NIO

typealias Future = EventLoopFuture

public struct Package : Codable {
    /// has the package been setup fully with its dependencies setup
    public var readPackageSwift: Bool = false
    /// packages we are dependent on
    var dependencies: Set<String>
    /// packages dependent on us
    var dependents: Set<String>
    /// error
    var error : String? {
        // if setting an error the package must have been read
        didSet { readPackageSwift = true}
    }
    
    public init() {
        self.dependencies = []
        self.dependents = []
    }
    
    public init(dependencies: [String]) {
        self.readPackageSwift = true
        self.dependencies = Set<String>(dependencies.map { Packages.cleanupName($0) })
        self.dependents = []
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // enocde dependencies and dependents in alphabetical order
        try container.encode(dependencies.map{$0}.sorted(by:{ return $0.split(separator: "/").last! < $1.split(separator: "/").last! }), forKey: .dependencies)
        try container.encode(dependents.map{$0}.sorted(by:{ return $0.split(separator: "/").last! < $1.split(separator: "/").last! }), forKey: .dependents)
        try container.encode(error, forKey: .error)
    }
    
    enum CodingKeys : String, CodingKey {
        case dependencies = "on"
        case dependents = "to"
        case error = "error"
    }
}

enum PackagesError : Swift.Error {
    case corruptDependencies
}

public class Packages {
    public typealias Container = [String: Package]
    public private(set) var packages : Container
    
    public init() throws {
        self.packages = [:]
        self.loader = try PackageLoader(onAdd: self.add, onError: self.addLoadingError)
    }
    
    public init(packages: Container) throws {
        self.packages = packages
        self.loader = try PackageLoader(onAdd: self.add, onError: self.addLoadingError)

        // flag all packages as read
        for key in self.packages.keys {
            self.packages[key]?.readPackageSwift = true
        }
    }
    
    /// add a package
    func add(name: String, package: Package) {
        let name = Packages.cleanupName(name)
        lock.lock()
        defer {
            lock.unlock()
        }
        
        var package = package
        // if package already exists then add the dependent of the original package to the new one
        if let package2 = packages[name] {
            guard package2.readPackageSwift != true else {return}
            package.dependents = package2.dependents
        }
        packages[name] = package
        
        for dependency in package.dependencies {
            // guard against invalid urls. If invalid remove from dependency list
            guard PackageLoader.isValidUrl(url: dependency) else {
                print("Error: removed dependency as the URL was invalid")
                packages[name]?.dependencies.remove(dependency)
                continue
            }
            let dependencyName = Packages.cleanupName(dependency)
            if packages[dependencyName] == nil {
                packages[dependencyName] = Package()
            }
            packages[dependencyName]!.dependents.insert(name)
        }
    }

    /// set loading package failed
    public func addLoadingError(name: String, error: Error) {
        print("Failed to load package from \(name) error: \(Packages.stringFromError(error))")
        let name = Packages.cleanupName(name)
        lock.lock()
        defer {
            lock.unlock()
        }
        
        // if package already exists
        let error = Packages.stringFromError(error)
        if packages[name] != nil {
            packages[name]?.error = error
        } else {
            var package = Package()
            package.error = error
            packages[name] = package
        }
    }
    
    /// import packages.json file
    /// - Parameters:
    ///   - url: URL of packages json file
    ///   - iterations: Number of iterations we will run emptying the package array after having added dependencies
    public func `import`(url: String, iterations : Int = 100) throws {
        // Load package names from url
        let packageNames = try loader.load(url: url, packages: self).map { Packages.cleanupName($0)}
        
        try loadPackages(packageNames, iterations: iterations)
        
    }
    
    /// Load list of packages
    /// - Parameters:
    ///   - packageNames: List of package URLs
    ///   - iterations: Number of iterations we will run emptying the package array after having added dependencies
    func loadPackages(_ packageNames: [String], iterations : Int = 100) throws {
        // remove duplicate packages, sort and remove packages we have already loaded
        var packageNames = Array(Set(packageNames)).sorted().compactMap { (name)->String? in
            let name = Packages.cleanupName(name)
            return packages[name] == nil ? name : nil
        }

        var iterations = iterations
        repeat {
            try loader.loadPackages(packageNames).wait()
            
            // verify we havent got stuck in a loop
            iterations -= 1
            guard iterations > 0 else { throw PackageLoaderError.looping }
            
            // create new list of packages containing packages that haven't been loaded
            packageNames = packages.compactMap {return !$0.value.readPackageSwift ? $0.key : nil}
        } while(packageNames.count > 0)
    }
    
    /// Remove package from dependency set, also needs to remove all of its dependecies
    /// - Parameter packageName: URL of package
    public func removePackage(_ packageName: String) throws {
        let name = Packages.cleanupName(packageName)
        guard let package = packages[name] else { return }
        // when you remove a package you have to remove it from its dependencies dependents lists
        for d in package.dependencies {
            guard var dependency = packages[d] else { throw PackagesError.corruptDependencies }
            dependency.dependents.remove(name)
        }
        // when you remove a package you have to remove it dependents
        for d in package.dependents {
            try removePackage(d)
        }
        packages[name] = nil
    }
    
    /// Remove packages filtered by including a string
    /// - Parameter filteredBy: String that packages need to contain to be removed
    public func removePackages(filteredBy: String) throws {
        let packages = self.packages.compactMap { (entry)->String? in
            if entry.key.contains(filteredBy) {
                return entry.key
            }
            return nil
        }
        try packages.forEach { try self.removePackage($0); print("Rebulding \($0)") }
    }
    
    /// save dependency file
    public func save(filename: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(packages)
        try data.write(to: URL(fileURLWithPath: filename))
    }

    /// convert error to string
    static func stringFromError(_ error: Swift.Error) -> String {
        switch error {
        case PackageLoaderError.invalidToolsVersion:
            return "Requires later version of Swift"
        case PackageLoaderError.invalidManifest:
            return "InvalidManifest"
        case HTTPLoader.HTTPError.failedToLoad(_):
            return "FailedToLoad"
        default:
            return "Unknown"
        }
    }
    
    /// convert name from github/repository.git to github/repository
    public static func cleanupName(_ packageName: String) -> String {
        var packageName = packageName.lowercased()
        // if package is recorded as git@github.com changes to https://github.com/
        if packageName.hasPrefix("git@github.com") {
            var split = packageName.split(separator: "/", omittingEmptySubsequences: false)
            let split2 = split[0].split(separator: ":")
            //guard split2.count > 1 else {return nil}
            // set user name
            split[0] = split2[1]
            split.insert("github.com", at:0)
            split.insert("", at:0)
            split.insert("https:", at:0)
            packageName = split.joined(separator: "/")
        }
        
        if packageName.suffix(4) == ".git" {
            // remove .git suffix
            return String(packageName.prefix(packageName.count - 4))
        } else if packageName.last == "/" {
            // ensure name doesn't end with "/"
            return String(packageName.dropLast())
        }
        return packageName
    }
    
    let lock = NSLock()
    var loader: PackageLoader!
    

}

