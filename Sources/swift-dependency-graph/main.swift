import Foundation
import NIO
import swift_dependency_graph_lib
import IOKit.pwr_mgt

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

let startTime = Date()
let id = System.preventSleep(reason: "Swift Dependency Graph")

let packages = Packages()
let rootPath = #file.split(separator: "/", omittingEmptySubsequences: false).dropLast(3).joined(separator: "/")
let url = "https://raw.githubusercontent.com/daveverwer/SwiftPMLibrary/master/packages.json"

do {
    try packages.import(url: url)
    try packages.save(filename: rootPath + "/dependencies.json")
} catch {
    print(error)
}
print("Dependency generation took \(Int(-startTime.timeIntervalSinceNow)) seconds")
if let id = id {
    System.allowSleep(id: id)
}
