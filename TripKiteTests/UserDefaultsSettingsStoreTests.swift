import XCTest
@testable import TripKite

final class UserDefaultsSettingsStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var store: UserDefaultsSettingsStore!

    override func setUp() {
        super.setUp()
        suiteName = "TripKiteTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        store = UserDefaultsSettingsStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        store = nil
        suiteName = nil
        super.tearDown()
    }

    func testDefaultReminderOption_WhenNothingStored_ReturnsNone() {
        XCTAssertEqual(store.defaultReminderOption(), .none)
    }

    func testSetDefaultReminderOption_RoundTripsValue() {
        store.setDefaultReminderOption(.minutesBefore15)
        XCTAssertEqual(store.defaultReminderOption(), .minutesBefore15)
    }

    func testSetDefaultReminderOption_RoundTripsAllCases() {
        for option in ReminderOption.allCases {
            store.setDefaultReminderOption(option)
            XCTAssertEqual(store.defaultReminderOption(), option, "Round-trip failed for \(option)")
        }
    }

    func testSetDefaultReminderOption_PersistsAcrossStoreInstances() {
        store.setDefaultReminderOption(.hourBefore1)
        let freshStore = UserDefaultsSettingsStore(defaults: defaults)
        XCTAssertEqual(freshStore.defaultReminderOption(), .hourBefore1)
    }

    func testReset_ClearsPersistedValue() {
        store.setDefaultReminderOption(.dayBefore1)
        store.reset()
        XCTAssertEqual(store.defaultReminderOption(), .none)
    }

    func testReset_OnEmptyStore_IsNoOp() {
        store.reset()
        XCTAssertEqual(store.defaultReminderOption(), .none)
    }

    func testDefaultReminderOption_WhenUnknownStringStored_ReturnsNone() {
        defaults.set("garbage-value-from-future-version", forKey: "TripKite.settings.defaultReminderOption")
        XCTAssertEqual(store.defaultReminderOption(), .none)
    }
}
