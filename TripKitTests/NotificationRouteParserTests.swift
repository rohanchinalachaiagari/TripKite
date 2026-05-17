import XCTest
@testable import TripKit

final class NotificationRouteParserTests: XCTestCase {

    func testParse_ValidTripIdReturnsRoute() {
        let tripId = UUID()
        let route = NotificationRouteParser.parse(["tripId": tripId.uuidString])
        XCTAssertEqual(route?.tripId, tripId)
        XCTAssertNil(route?.itemId)
    }

    func testParse_ValidTripIdAndItemIdReturnsBoth() {
        let tripId = UUID()
        let itemId = UUID()
        let route = NotificationRouteParser.parse([
            "tripId": tripId.uuidString,
            "itemId": itemId.uuidString
        ])
        XCTAssertEqual(route?.tripId, tripId)
        XCTAssertEqual(route?.itemId, itemId)
    }

    func testParse_MissingTripIdReturnsNil() {
        XCTAssertNil(NotificationRouteParser.parse(["other": "value"]))
    }

    func testParse_TripIdInvalidUUIDReturnsNil() {
        XCTAssertNil(NotificationRouteParser.parse(["tripId": "not-a-uuid"]))
    }

    func testParse_ItemIdInvalidUUIDIsDropped() {
        let tripId = UUID()
        let route = NotificationRouteParser.parse([
            "tripId": tripId.uuidString,
            "itemId": "garbage"
        ])
        XCTAssertEqual(route?.tripId, tripId)
        XCTAssertNil(route?.itemId)
    }

    func testParse_TripIdAsNonStringReturnsNil() {
        XCTAssertNil(NotificationRouteParser.parse(["tripId": 42]))
    }
}
