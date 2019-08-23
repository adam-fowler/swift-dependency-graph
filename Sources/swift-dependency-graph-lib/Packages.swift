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
    
    enum CodingKeys : String, CodingKey {
        case dependencies = "on"
        case dependents = "to"
        case error = "error"
    }
}

public class Packages {
    public private(set) var packages : [String: Package] = [:]
    
    public init() {}
    
    /// add a package
    public func add(name: String, package: Package) {
        let name = Packages.cleanupName(name)
        semaphore.wait()
        defer {
            semaphore.signal()
        }
        
        var package = package
        // if package already exists then add the dependent of the original package to the new one
        if let package2 = packages[name] {
            assert(package2.readPackageSwift != true)
            package.dependents = package2.dependents
        }
        packages[name] = package
        
        for dependency in package.dependencies {
            guard Packages.isValidUrl(url: dependency) else { continue }
            let dependencyName = Packages.cleanupName(dependency)
            if packages[dependencyName] == nil {
                packages[dependencyName] = Package()
            }
            packages[dependencyName]!.dependents.insert(name)
        }
    }
    
    /// set loading package failed
    public func addLoadingError(name: String, error: Error) {
        let name = Packages.cleanupName(name)
        semaphore.wait()
        defer {
            semaphore.signal()
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
    
    /// convert error to string
    static func stringFromError(_ error: Error) -> String {
        switch error {
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
            return String(packageName.prefix(packageName.count - 4))
        } else if packageName.last == "/" {
            return String(packageName.dropLast())
        }
        return packageName
    }
    
    /// get package URL from github repository name
    static func getPackageUrl(url: String, version: String? = nil) -> String? {
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
            split.append("master/Package@swift-\(version).swift")
        } else {
            split.append("master/Package.swift")
        }
        
        return split.joined(separator: "/")
    }
    
    /// return if this is a valid repository name
    static func isValidUrl(url: String) -> Bool {
        var split = url.split(separator: "/", omittingEmptySubsequences: false)
        if split[0].hasPrefix("git@github.com") && split.count == 2
            || split.count > 4 && split[2] == "github.com"
            || split.count > 4 && split[2] == "gitlab.com" {
            return true
        }
        return false
    }
    
    public func `import`(url: String, iterations : Int = 100) throws {
        let loader = try PackageLoader(onAdd: { name, package in
            self.add(name: name, package: package)
        }, onError: { name, error in
            print("Failed to load package from \(name)")
            self.addLoadingError(name: name, error: error)
        })

        // Load package names from url
        var packageNames = try loader.load(url: url, packages: self)
        
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
    
    public func save(filename: String) throws {
        let data = try JSONEncoder().encode(packages)
        try data.write(to: URL(fileURLWithPath: filename))
    }
    
    let semaphore = DispatchSemaphore(value: 1)
}

