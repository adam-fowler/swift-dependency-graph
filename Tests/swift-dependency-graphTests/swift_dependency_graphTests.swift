import XCTest
@testable import swift_dependency_graph_lib

func attempt(function: () throws -> ()) {
    do {
        try function()
    } catch {
        XCTFail(error.localizedDescription)
    }
}

final class swift_dependency_graphTests: XCTestCase {
    func testPackagesCleanupName() {
        XCTAssertEqual(Packages.cleanupName("https://github.com/user/repository"), "https://github.com/user/repository")
        XCTAssertEqual(Packages.cleanupName("https://github.com/user/repository/"), "https://github.com/user/repository")
        XCTAssertEqual(Packages.cleanupName("https://github.com/user/repository.git"), "https://github.com/user/repository")
    }

    func testLoadPackageTest() {
        attempt {
            try PackageLoader(onAdd: { _,_ in }).addPackage(url: "https://github.com/adam-fowler/swift-dependency-graph").wait()
        }
    }
    
    func testLoadRedirectPackageTest() {
        attempt {
            try PackageLoader(onAdd: { _,_ in }).addPackage(url: "http://github.com/adam-fowler/swift-dependency-graph").wait()
        }
    }
    
    func testLoadGitlabWithUppercaseLetterPackageTest() {
        attempt {
            try PackageLoader(onAdd: { _,_ in }).addPackage(url: "https://gitlab.com/Mordil/swift-redi-stack").wait()
        }
    }
    
    func testLoadGitAtGitHubPackageTest() {
        attempt {
            try PackageLoader(onAdd: { _,_ in }).addPackage(url: "git@github.com:adam-fowler/swift-dependency-graph").wait()
        }
    }
    
    func testLoadPackageV4Test() {
        attempt {
            try PackageLoader(onAdd: { _,_ in }).addPackage(url: "https://github.com/getguaka/env.git").wait()
        }
    }
    
    func testLoadPackageV4_2Test() {
        attempt {
            try PackageLoader(onAdd: { _,_ in }).addPackage(url: "https://github.com/apple/swift-protobuf").wait()
        }
    }
    
    // invalid manifest (trying to load Package.swift when it is for swift 3)
    /*func testLoadPackageSwiftV4Test() {
        attempt {
            try PackageLoader(onAdd: { _,_ in }).addPackage(url: "https://github.com/jdhealy/prettycolors").wait()
        }
    }*/
    /*func testLoadPackageV5_1Test() {
        attempt {
            try PackageLoader(onAdd: { _,_ in }).addPackage(url: "https://github.com/freak4pc/combinecocoa.git").wait()
        }
    }*/
    
    /*func testLoadNonMasterPackageTest() {
        attempt {
            try PackageLoader(onAdd: { _,_ in }).addPackage(url: "https://github.com/Flinesoft/AnyMenu.git").wait()
        }
    }*/
    
    func testLoadErroringPackage() {
        attempt {
            // Package.swift on master branch is corrupt but release branch version is fine
            //try PackageLoader(onAdd: { _,_ in }).addPackage(url: "https://github.com/httpswift/swifter.git").wait()
            // weird order of loading, there is a 4.0 and a standard
            //try PackageLoader(onAdd: { _,_ in }).addPackage(url: "https://github.com/vapor/json.git").wait()
            // ditto
            //try PackageLoader(onAdd: { _,_ in }).addPackage(url: "https://github.com/vapor/node").wait()
            //version 3.1
            //try PackageLoader(onAdd: { _,_ in }).addPackage(url: "https://github.com/vzsg/ed25519").wait()
            // empty Package
            //try PackageLoader(onAdd: { _,_ in }).addPackage(url: "https://github.com/dentelezhkin/dwifft").wait()
            // no master branch but there is a release with package available
            //try PackageLoader(onAdd: { _,_ in }).addPackage(url: "https://github.com/tomlokhorst/xcodeedit").wait()
        }
    }
    
    func testLoadPackageJson() {
        attempt {
            let rootFolder = #file
                .split(separator:"/", omittingEmptySubsequences: false)
                .dropLast(1)
                .map { String(describing: $0) }
                .joined(separator:"/")
            let packages = Packages()
            try packages.import(url: rootFolder + "/packages.json", iterations: 4)
            
            XCTAssertNotNil(packages.packages["https://github.com/adam-fowler/swift-dependency-graph"])
            XCTAssertNotNil(packages.packages["https://github.com/apple/swift-package-manager"])
            XCTAssertNotNil(packages.packages["https://github.com/apple/swift-llbuild"])
        }
    }
    
    static var allTests = [
        ("testPackagesCleanupName", testPackagesCleanupName),
    ]
}
