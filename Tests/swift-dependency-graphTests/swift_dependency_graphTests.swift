import XCTest
@testable import swift_dependency_graph_lib

final class swift_dependency_graphTests: XCTestCase {
    func testPackagesCleanupName() {
        XCTAssertEqual(Packages.cleanupName("https://github.com/user/repository"), "https://github.com/user/repository")
        XCTAssertEqual(Packages.cleanupName("https://github.com/user/repository/"), "https://github.com/user/repository")
        XCTAssertEqual(Packages.cleanupName("https://github.com/user/repository.git"), "https://github.com/user/repository")
    }

    static var allTests = [
        ("testPackagesCleanupName", testPackagesCleanupName),
    ]
}
