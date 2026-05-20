import XCTest
@testable import TripKite

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

    // Raw values are persisted by SettingsStore — pinning them here so a
    // future case rename can't silently invalidate stored user defaults.
    func testRawValues_AreStable() {
        XCTAssertEqual(ReminderOption.none.rawValue, "none")
        XCTAssertEqual(ReminderOption.atStart.rawValue, "atStart")
        XCTAssertEqual(ReminderOption.minutesBefore5.rawValue, "5min")
        XCTAssertEqual(ReminderOption.minutesBefore15.rawValue, "15min")
        XCTAssertEqual(ReminderOption.minutesBefore30.rawValue, "30min")
        XCTAssertEqual(ReminderOption.hourBefore1.rawValue, "1hour")
        XCTAssertEqual(ReminderOption.dayBefore1.rawValue, "1day")
    }

    func testRawValue_RoundTripsAllCases() {
        for option in ReminderOption.allCases {
            XCTAssertEqual(ReminderOption(rawValue: option.rawValue), option)
        }
    }
}
