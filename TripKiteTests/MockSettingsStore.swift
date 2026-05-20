import Foundation
@testable import TripKite

final class MockSettingsStore: SettingsStore, @unchecked Sendable {
    private let lock = NSLock()
    private var _defaultReminderOption: ReminderOption = .none
    private var _resetCount = 0

    func defaultReminderOption() -> ReminderOption {
        lock.lock(); defer { lock.unlock() }
        return _defaultReminderOption
    }

    func setDefaultReminderOption(_ option: ReminderOption) {
        lock.lock(); defer { lock.unlock() }
        _defaultReminderOption = option
    }

    func reset() {
        lock.lock(); defer { lock.unlock() }
        _defaultReminderOption = .none
        _resetCount += 1
    }

    var resetCount: Int {
        lock.lock(); defer { lock.unlock() }
        return _resetCount
    }
}
