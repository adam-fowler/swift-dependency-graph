import Foundation
import NIO
import swift_dependency_graph_lib

let packages = Packages()
//let url = "https://raw.githubusercontent.com/adam-fowler/swift-dependency-graph/master/packages.json"
let url = "https://raw.githubusercontent.com/daveverwer/SwiftPMLibrary/master/packages.json"

try packages.load(url: url)
try packages.save()
