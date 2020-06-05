import Foundation
import NIO
import swift_dependency_graph_lib
import IOKit.pwr_mgt
import ArgumentParser

class System {
    /// prevent system going to sleep. Returns an id you have to supply to re-enable system sleep
    class func preventSleep(reason:String) -> IOPMAssertionID? {
        var assertionID = IOPMAssertionID(0)
        let success = IOPMAssertionCreateWithName(kIOPMAssertPreventUserIdleSystemSleep as CFString,
                                                  IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                                  reason as CFString,
                                                  &assertionID)
        if success == kIOReturnSuccess {
            return assertionID
        }
        return nil
    }
    
    /// re-enable system sleep. Pass in the id returned from the matching preventSleep() call
    class func allowSleep(id : IOPMAssertionID) {
        IOPMAssertionRelease(id)
    }
}

let rootPath = #file.split(separator: "/", omittingEmptySubsequences: false).dropLast(3).joined(separator: "/")

struct SwiftDependencyGraph: ParsableCommand {
    // output path
    @Option(default: rootPath + "/html/dependencies.json") var output: String
    
    // rebuild all flag
    @Flag(help: "Rebuild all packages") var rebuildAll: Bool
    
    // rebuild package option
    @Option(name: .shortAndLong, help: "Rebuild package and its dependents") var rebuild: String?
    
    func run() throws {
        let startTime = Date()
        let id = System.preventSleep(reason: "Swift Dependency Graph")
        defer {
            if let id = id {
                System.allowSleep(id: id)
            }
        }

        let url = "https://raw.githubusercontent.com/daveverwer/SwiftPMLibrary/master/packages.json"

        do {
            let packages: Packages
            // load json that is already there
            if !rebuildAll {
                let data = try Data(contentsOf: URL(fileURLWithPath: self.output))
                let packageList = try JSONDecoder().decode(Packages.Container.self, from: data)
                packages = try Packages(packages: packageList)
                if let rebuild = rebuild {
                    try packages.removePackages(filteredBy: rebuild)
                }
            } else {
                packages = try Packages()
            }
            try packages.import(url: url)
            try packages.save(filename: output)
        } catch {
            print(error)
        }
        print("Dependency generation took \(Int(-startTime.timeIntervalSinceNow)) seconds")
    }
}

SwiftDependencyGraph.main()
