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
            try PackageLoader(addPackage: { _,_ in }).addPackage(url: "https://github.com/adam-fowler/swift-dependency-graph").wait()
        }
    }
    
    func testLoadRedirectPackageTest() {
        attempt {
            try PackageLoader(addPackage: { _,_ in }).addPackage(url: "http://github.com/adam-fowler/swift-dependency-graph").wait()
        }
    }
    
    func testLoadGitlabWithUppercaseLetterPackageTest() {
        attempt {
            try PackageLoader(addPackage: { _,_ in }).addPackage(url: "https://gitlab.com/Mordil/swift-redi-stack").wait()
        }
    }
    
    func testLoadGitAtGitHubPackageTest() {
        attempt {
            try PackageLoader(addPackage: { _,_ in }).addPackage(url: "git@github.com:adam-fowler/swift-dependency-graph").wait()
        }
    }
    
    func testLoadPackageV4Test() {
        attempt {
            try PackageLoader(addPackage: { _,_ in }).addPackage(url: "https://github.com/getguaka/env.git").wait()
        }
    }
    
    /*func testLoadPackageV5_1Test() {
        attempt {
            try PackageLoader(addPackage: { _,_ in }).addPackage(url: "https://github.com/freak4pc/combinecocoa.git").wait()
        }
    }*/
    
    /*func testLoadNonMasterPackageTest() {
        attempt {
            try PackageLoader(addPackage: { _,_ in }).addPackage(url: "https://github.com/Flinesoft/AnyMenu.git").wait()
        }
    }*/
    
    static var allTests = [
        ("testPackagesCleanupName", testPackagesCleanupName),
    ]
}
