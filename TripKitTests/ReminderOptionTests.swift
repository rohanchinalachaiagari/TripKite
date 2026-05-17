import XCTest
@testable import TripKit

final class ReminderOptionTests: XCTestCase {

    func testOffset_NoneIsNil() {
        XCTAssertNil(ReminderOption.none.offset)
    }

    func testOffset_PresetsHaveExpectedSeconds() {
        XCTAssertEqual(ReminderOption.atStart.offset, 0)
        XCTAssertEqual(ReminderOption.minutesBefore5.offset, 300)
        XCTAssertEqual(ReminderOption.minutesBefore15.offset, 900)
        XCTAssertEqual(ReminderOption.minutesBefore30.offset, 1800)
        XCTAssertEqual(ReminderOption.hourBefore1.offset, 3600)
        XCTAssertEqual(ReminderOption.dayBefore1.offset, 86_400)
    }

    func testMatch_NilOffsetReturnsNone() {
        XCTAssertEqual(ReminderOption.match(offset: nil), .none)
    }

    func testMatch_RoundTripsAllPresets() {
        for option in ReminderOption.allCases {
            XCTAssertEqual(ReminderOption.match(offset: option.offset), option)
        }
    }

    func testMatch_NonPresetFallsBackToNone() {
        XCTAssertEqual(ReminderOption.match(offset: 17 * 60), .none)
    }
}
