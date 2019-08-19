import Foundation
import NIO
import swift_dependency_graph_lib

let packages = Packages()
let rootPath = #file.split(separator: "/", omittingEmptySubsequences: false).dropLast(3).joined(separator: "/")
//let url = rootPath + "/packages.json"
let url = "https://raw.githubusercontent.com/daveverwer/SwiftPMLibrary/master/packages.json"

do {
    try packages.load(url: url)
    try packages.save(filename: rootPath + "/dependencies.json")
} catch {
    print(error)
}
