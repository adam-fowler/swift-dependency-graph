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
    
    public init() {
        self.dependencies = []
        self.dependents = []
    }
    
    public init(dependencies: [String]) {
        self.readPackageSwift = true
        self.dependencies = Set<String>(dependencies)
        self.dependents = []
    }
    
    enum CodingKeys : String, CodingKey {
        case dependencies = "dependencies"
        case dependents = "dependents"
    }
}

public class Packages {
    public private(set) var packages : [String: Package] = [:]
    
    public init() {}
    
    // add a package
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
            let name = Packages.cleanupName(dependency)
            if packages[name] == nil {
                packages[name] = Package()
            }
            packages[name]!.dependents.insert(name)
        }
    }
    
    /// convert name from github/repository.git to github/repository/
    public static func cleanupName(_ packageName: String) -> String {
        if packageName.suffix(4) == ".git" {
            return String(packageName.prefix(packageName.count - 4))
        } else if packageName.last == "/" {
            return String(packageName.dropLast())
        }
        return packageName
    }
    
    /// convert name from github/repository.git to github/repository/
    public static func cleanupName(_ packageName: Substring) -> Substring {
        if packageName.suffix(4) == ".git" {
            return packageName.prefix(packageName.count - 4)
        } else if packageName.last == "/" {
            return packageName.dropLast()
        }
        return packageName
    }
    
    /// get package URL from github repository name
    static func getPackageUrl(url: String) -> String? {
        // get Package.swift URL
        var split = url.split(separator: "/", omittingEmptySubsequences: false)
        if split.last == "" {
            split = split.dropLast()
        }
        
        // bloody trouble makers
        if split[0].hasPrefix("git@github.com") {
            let split2 = split[0].split(separator: ":")
            guard split2.count > 1 else {return nil}
            // set user name
            split[0] = split2[1]
            split.insert("raw.githubusercontent.com", at:0)
            split.insert("", at:0)
            split.insert("https:", at:0)
        } else if split.count > 2 && split[2] == "github.com" {
            split[2] = "raw.githubusercontent.com"
        }
        
        let last = split.count - 1
        split[last] = Packages.cleanupName(split[last])
        
        if split.count > 2 && split[2] == "gitlab.com" {
            split.append("raw")
        }
        
        split.append("master/Package.swift")
        
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
    
    public func load(url: String) throws {
        let loader = try PackageLoader { name, package in
            self.add(name: name, package: package)
        }
        try loader.load(url: url, packages: self)
    }
    
    public func save(filename: String) throws {
        let data = try JSONEncoder().encode(packages)
        try data.write(to: URL(fileURLWithPath: filename))
    }
    
    let semaphore = DispatchSemaphore(value: 1)
}

