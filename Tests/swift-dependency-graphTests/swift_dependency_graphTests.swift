import XCTest
@testable import swift_dependency_graph

final class swift_dependency_graphTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(swift_dependency_graph().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
