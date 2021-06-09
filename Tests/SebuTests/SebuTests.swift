import XCTest
@testable import Sebu

final class SebuTests: XCTestCase {
    
    struct TestStruct: Codable {
        var id = UUID()
        var test = "test"
    }
    
    func saveObject() {
        Sebu.save(TestStruct(), withName: "test", expiration: nil)
    }
}
