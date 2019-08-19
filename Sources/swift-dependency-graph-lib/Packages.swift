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
            if packages[dependency] == nil {
                packages[dependency] = Package()
            }
            packages[dependency]!.dependents.insert(name)
        }
    }
    
    /// convert name from github/repository.git to github/repository/
    public static func cleanupName(_ packageName: Substring) -> Substring {
        if packageName.suffix(4) == ".git" {
            return packageName.prefix(packageName.count - 4) + "/"
        } else if packageName.last != "/" {
            return packageName+"/"
        }
        return packageName
    }
    
    public func load(url: String) throws {
        let loader = try PackageLoader { name, package in
            self.add(name: name, package: package)
        }
        try loader.load(url: url, packages: self)
    }
    
    public func save() throws {
        let data = try JSONEncoder().encode(packages)
        try data.write(to: URL(fileURLWithPath: "dependencies.json"))
    }
    
    let semaphore = DispatchSemaphore(value: 1)
}

