import XCTest
@testable import TripKite

@MainActor
final class SettingsViewModelTests: XCTestCase {

    // MARK: - Default reminder

    func testInit_LoadsDefaultReminderFromStore() {
        let store = MockSettingsStore()
        store.setDefaultReminderOption(.hourBefore1)
        let vm = makeViewModel(store: store)
        XCTAssertEqual(vm.defaultReminderOption, .hourBefore1)
    }

    func testSettingDefaultReminder_WritesThroughToStore() {
        let store = MockSettingsStore()
        let vm = makeViewModel(store: store)
        vm.defaultReminderOption = .minutesBefore15
        XCTAssertEqual(store.defaultReminderOption(), .minutesBefore15)
    }

    func testSettingDefaultReminderToNonNone_FromNotDetermined_RequestsAuthorization() async {
        let notifications = MockNotificationSchedulingService()
        await notifications.setAuthorizationStatus(.notDetermined)
        let vm = makeViewModel(notifications: notifications)
        await vm.refreshAuthorizationStatus()

        vm.defaultReminderOption = .minutesBefore15
        try? await Task.sleep(nanoseconds: 50_000_000)

        let requestCount = await notifications.authorizationRequestCount
        XCTAssertEqual(requestCount, 1)
    }

    func testSettingDefaultReminderToNonNone_WhenAlreadyAuthorized_DoesNotRequestAgain() async {
        let notifications = MockNotificationSchedulingService()
        await notifications.setAuthorizationStatus(.authorized)
        let vm = makeViewModel(notifications: notifications)
        await vm.refreshAuthorizationStatus()

        vm.defaultReminderOption = .minutesBefore15
        try? await Task.sleep(nanoseconds: 50_000_000)

        let requestCount = await notifications.authorizationRequestCount
        XCTAssertEqual(requestCount, 0)
    }

    func testSettingDefaultReminderToNone_DoesNotRequestAuthorization() async {
        let notifications = MockNotificationSchedulingService()
        await notifications.setAuthorizationStatus(.notDetermined)
        let vm = makeViewModel(notifications: notifications)
        await vm.refreshAuthorizationStatus()
        vm.defaultReminderOption = .minutesBefore15
        try? await Task.sleep(nanoseconds: 50_000_000)

        // Reset request count for a clean assertion on the next transition.
        // (We can't reset the mock — it stays at 1. So we capture the baseline.)
        let baseline = await notifications.authorizationRequestCount

        vm.defaultReminderOption = .none
        try? await Task.sleep(nanoseconds: 50_000_000)

        let after = await notifications.authorizationRequestCount
        XCTAssertEqual(after, baseline)
    }

    // MARK: - Authorization status

    func testRefreshAuthorizationStatus_PullsFromService() async {
        let notifications = MockNotificationSchedulingService()
        await notifications.setAuthorizationStatus(.denied)
        let vm = makeViewModel(notifications: notifications)

        await vm.refreshAuthorizationStatus()

        XCTAssertEqual(vm.authorizationStatus, .denied)
    }

    // MARK: - Clear All Data

    func testRequestClearAllData_SetsPendingConfirmation() {
        let vm = makeViewModel()
        XCTAssertFalse(vm.pendingClearConfirmation)
        vm.requestClearAllData()
        XCTAssertTrue(vm.pendingClearConfirmation)
    }

    func testConfirmClearAllData_CallsDataManagementAndRefreshesDefault() async {
        let store = MockSettingsStore()
        store.setDefaultReminderOption(.hourBefore1)
        let data = MockDataManagementService()
        let vm = makeViewModel(store: store, data: data)
        XCTAssertEqual(vm.defaultReminderOption, .hourBefore1)

        // Simulate the side effect that real clearAllData would have on the store.
        // Our mock data service only counts the call; the store has to be reset
        // separately for the VM to observe the change.
        vm.requestClearAllData()
        store.reset()
        await vm.confirmClearAllData()

        let clearCount = await data.clearCallCount
        XCTAssertEqual(clearCount, 1)
        XCTAssertFalse(vm.pendingClearConfirmation)
        XCTAssertEqual(vm.defaultReminderOption, .none, "Picker should reflect the reset store")
        XCTAssertNil(vm.errorMessage)
    }

    func testConfirmClearAllData_OnFailure_SetsErrorMessage() async {
        let data = MockDataManagementService()
        struct BoomError: LocalizedError { var errorDescription: String? { "Boom" } }
        await data.setClearError(BoomError())
        let vm = makeViewModel(data: data)

        vm.requestClearAllData()
        await vm.confirmClearAllData()

        XCTAssertEqual(vm.errorMessage, "Boom")
        XCTAssertFalse(vm.pendingClearConfirmation)
    }

    // MARK: - Helpers

    private func makeViewModel(
        store: MockSettingsStore = MockSettingsStore(),
        data: MockDataManagementService = MockDataManagementService(),
        notifications: MockNotificationSchedulingService = MockNotificationSchedulingService()
    ) -> SettingsViewModel {
        SettingsViewModel(
            settingsStore: store,
            dataManagement: data,
            notificationService: notifications
        )
    }
}
