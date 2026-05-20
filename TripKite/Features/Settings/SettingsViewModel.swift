import Foundation
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var defaultReminderOption: ReminderOption {
        didSet {
            // Persist the choice. Writes are idempotent on the same value so
            // the duplicate write during init is harmless.
            settingsStore.setDefaultReminderOption(defaultReminderOption)
            let previous = oldValue
            Task { await requestAuthorizationIfNeeded(previous: previous) }
        }
    }

    @Published private(set) var authorizationStatus: NotificationAuthorizationStatus = .notDetermined
    @Published private(set) var isClearing = false
    @Published var errorMessage: String?
    @Published var pendingClearConfirmation = false

    private let settingsStore: SettingsStore
    private let dataManagement: DataManagementService
    private let notificationService: NotificationSchedulingService

    init(
        settingsStore: SettingsStore,
        dataManagement: DataManagementService,
        notificationService: NotificationSchedulingService
    ) {
        self.settingsStore = settingsStore
        self.dataManagement = dataManagement
        self.notificationService = notificationService
        self.defaultReminderOption = settingsStore.defaultReminderOption()

        // Kick off the authorization read here so the published value
        // converges quickly regardless of whether the view's `.task` fires.
        // This matters when the SettingsView is created before the user
        // ever navigates to it, or when a hot-swapped build replaces the
        // app process without re-triggering view lifecycle hooks.
        Task { await refreshAuthorizationStatus() }
    }

    func refreshAuthorizationStatus() async {
        authorizationStatus = await notificationService.currentAuthorizationStatus()
    }

    // Mirrors the editor's lazy-permission flow. The first time the user
    // selects a non-None default, ask for authorization. Subsequent changes
    // don't re-prompt — iOS only surfaces the system prompt once anyway.
    //
    // The status is queried fresh here rather than read from the cached
    // `authorizationStatus`. The cache may not yet be loaded when this
    // runs (didSet can fire before the init Task or .task completes),
    // and the system value is the only one that decides whether to prompt.
    private func requestAuthorizationIfNeeded(previous: ReminderOption) async {
        guard previous == .none, defaultReminderOption != .none else { return }
        let currentStatus = await notificationService.currentAuthorizationStatus()
        authorizationStatus = currentStatus
        guard currentStatus == .notDetermined else { return }
        _ = await notificationService.requestAuthorization()
        authorizationStatus = await notificationService.currentAuthorizationStatus()
    }

    func requestClearAllData() {
        pendingClearConfirmation = true
    }

    func confirmClearAllData() async {
        pendingClearConfirmation = false
        isClearing = true
        defer { isClearing = false }
        do {
            try await dataManagement.clearAllData()
            // The settings store was reset as part of the wipe; pull the new
            // value back into the published property so the picker updates.
            defaultReminderOption = settingsStore.defaultReminderOption()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
