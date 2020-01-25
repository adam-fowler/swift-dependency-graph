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
    func testLoadPackageSwiftV4Test() {
        attempt {
            try PackageLoader(onAdd: { _,_ in }).addPackage(url: "https://github.com/jdhealy/prettycolors").wait()
            try PackageLoader(onAdd: { _,_ in }).addPackage(url: "https://github.com/vapor/json.git").wait()
        }
    }
    
    func testLoadPackageV5_1Test() {
        attempt {
            try PackageLoader(onAdd: { _,_ in }).addPackage(url: "https://github.com/Jimmy-Lee/Networking.git").wait()
        }
    }
    
    func testOnReleaseNotMaster() {
        attempt {
            // Package.swift on master branch is corrupt but release branch version is fine
            try PackageLoader(onAdd: { _,_ in }).addPackage(url: "https://github.com/httpswift/swifter.git").wait()
            // no master branch but there is a release with package available
            try PackageLoader(onAdd: { _,_ in }).addPackage(url: "https://github.com/tomlokhorst/xcodeedit").wait()
        }
    }

    func testReleasesInvalidVersionTags() {
        attempt {
            // Release numbers have a v suffix
            try PackageLoader(onAdd: { _,_ in }).addPackage(url: "https://github.com/Bilue/ContentFittingWebView").wait()
        }
    }
    
    func testReleasesNumbersNotFormattedCorrectly() {
        attempt {
            // Release numbers are incorrect using major.minor not major.minor.patch
            try PackageLoader(onAdd: { _,_ in }).addPackage(url: "https://github.com/Alecrim/AlecrimAsyncKit").wait()
            try PackageLoader(onAdd: { _,_ in }).addPackage(url: "https://github.com/alexdrone/Store").wait()
        }
    }
    
    func testReleaseNumbersThatGoHigherThanNine() {
        attempt {
            // Releases are sorted alphabetically. Need to create version object for release and sort those
            try PackageLoader(onAdd: { _,_ in }).addPackage(url: "https://github.com/Carthage/Commandant").wait()
        }
    }

    func testOnMasterButNotRelease() {
        attempt {
            // Package.swift doesn't exist in the branch, while there is one on master
            try PackageLoader(onAdd: { _,_ in }).addPackage(url: "https://github.com/abdullahselek/TakeASelfie").wait()
        }
    }
    
    func testLoadNonMasterPackageTest() {
        attempt {
            // Package.swift not on master and there are no releases
            try PackageLoader(onAdd: { _,_ in }).addPackage(url: "https://github.com/Flinesoft/AnyMenu.git").wait()
        }
    }
    
    func testLoadingDependencyWithWWWPrefix() throws {
        let packages = try Packages()
        try packages.loadPackages(["https://github.com/krad/memento.git"])
        XCTAssertNotNil(packages.packages["https://www.github.com/krad/clibavcodec"])
    }
    
    func testLoadErroringPackage() {
        attempt {
            //
            //try PackageLoader(onAdd: { _,_ in }).addPackage(url: "https://github.com/kthomas/jwtdecode.swift").wait()
        }
    }
        
    /*
     Failed to load package from https://github.com/enablex/VCXSocket.git error: FailedToLoad Doesn't exist
     Failed to load package from https://github.com/mdaxter/bignumgmp.git error: InvalidManifest empty Package.swift
     Failed to load package from https://github.com/vzsg/ed25519.git error: InvalidManifest empty Package.swift
     Failed to load package from https://github.com/kthomas/jwtdecode.swift.git error: FailedToLoad doesn't exist
     Failed to load package from https://github.com/dentelezhkin/dwifft.git error: InvalidManifest empty Package.swift
     Failed to load package from https://github.com/kthomas/uickeychainstore.git error: FailedToLoad doesn't exist
     */
    
    
    func testLoadPackageJson() {
        attempt {
            let rootFolder = #file
                .split(separator:"/", omittingEmptySubsequences: false)
                .dropLast(1)
                .map { String(describing: $0) }
                .joined(separator:"/")
            let packages = try Packages()
            try packages.import(url: rootFolder + "/packages.json", iterations: 8)
            
            XCTAssertNotNil(packages.packages["https://github.com/adam-fowler/swift-dependency-graph"])
            XCTAssertNotNil(packages.packages["https://github.com/apple/swift-package-manager"])
            XCTAssertNotNil(packages.packages["https://github.com/apple/swift-llbuild"])
            XCTAssertNotNil(packages.packages["https://github.com/enablex/vcxsocket"]?.error)
        }
    }
    
    static var allTests = [
        ("testPackagesCleanupName", testPackagesCleanupName),
    ]
}
