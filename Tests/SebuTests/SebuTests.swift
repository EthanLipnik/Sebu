@testable import Sebu
import XCTest

final class SebuTests: XCTestCase {
    struct TestStruct: Codable {
        var id = UUID()
        var test = "test"
    }

    @MainActor
    func testSaveObject() throws {
        try Sebu.default.set(TestStruct(), withName: "test", expiration: nil)
    }
}
