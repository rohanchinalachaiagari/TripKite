import Foundation

// Persistence for user-facing settings. The protocol is intentionally
// synchronous — backing storage is UserDefaults today and there's no value in
// making every read async. If a future implementation needs network or async
// I/O (e.g., iCloud-backed settings), the protocol can be replaced or wrapped
// then; today's call sites would just need a small adapter.
protocol SettingsStore: Sendable {
    func defaultReminderOption() -> ReminderOption
    func setDefaultReminderOption(_ option: ReminderOption)

    // Resets every persisted setting to its built-in default. Used by
    // DataManagementService.clearAllData as part of the full wipe.
    func reset()
}

nonisolated final class UserDefaultsSettingsStore: SettingsStore, @unchecked Sendable {
    private enum Key {
        static let defaultReminderOption = "TripKite.settings.defaultReminderOption"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func defaultReminderOption() -> ReminderOption {
        guard let raw = defaults.string(forKey: Key.defaultReminderOption),
              let option = ReminderOption(rawValue: raw) else {
            return .none
        }
        return option
    }

    func setDefaultReminderOption(_ option: ReminderOption) {
        defaults.set(option.rawValue, forKey: Key.defaultReminderOption)
    }

    func reset() {
        defaults.removeObject(forKey: Key.defaultReminderOption)
    }
}
