import XCTest
@testable import TripKite

final class LocationActionAvailabilityTests: XCTestCase {

    func testActions_BothFieldsPresent_ReturnsAllThree() {
        let actions = LocationActionAvailability.actions(
            name: "Park Hyatt",
            address: "3-7-1 Nishi Shinjuku"
        )
        XCTAssertEqual(actions, [.openInMaps, .copyAddress, .copyLocationName])
    }

    func testActions_AddressOnly_OmitsCopyLocationName() {
        let actions = LocationActionAvailability.actions(
            name: "",
            address: "221B Baker Street"
        )
        XCTAssertEqual(actions, [.openInMaps, .copyAddress])
    }

    func testActions_NameOnly_OmitsCopyAddress() {
        let actions = LocationActionAvailability.actions(
            name: "Café de Flore",
            address: ""
        )
        XCTAssertEqual(actions, [.openInMaps, .copyLocationName])
    }

    func testActions_BothBlank_ReturnsEmpty() {
        XCTAssertTrue(LocationActionAvailability.actions(name: "", address: "").isEmpty)
    }

    func testActions_BothWhitespaceOnly_TreatsAsBlank() {
        XCTAssertTrue(LocationActionAvailability.actions(name: "   ", address: "\t \n").isEmpty)
    }

    func testActions_NameWhitespaceAddressPresent_OnlyAddressActions() {
        let actions = LocationActionAvailability.actions(name: "   ", address: "1 Apple Park Way")
        XCTAssertEqual(actions, [.openInMaps, .copyAddress])
    }

    func testActions_AddressWhitespaceNamePresent_OnlyNameActions() {
        let actions = LocationActionAvailability.actions(name: "Apple Park", address: "   ")
        XCTAssertEqual(actions, [.openInMaps, .copyLocationName])
    }
}
