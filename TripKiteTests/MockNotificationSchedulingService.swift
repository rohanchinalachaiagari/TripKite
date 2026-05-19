import Foundation
@testable import TripKite

final actor MockNotificationSchedulingService: NotificationSchedulingService {
    private(set) var scheduleCalls: [ItineraryItem] = []
    private(set) var itemCancellations: [UUID] = []
    private(set) var tripCancellations: [UUID] = []
    private(set) var authorizationRequestCount = 0
    private(set) var authorizationStatusQueryCount = 0

    private var status: NotificationAuthorizationStatus = .authorized
    private var grantOnRequest: Bool = true
    private var scheduleError: Error?

    func setAuthorizationStatus(_ value: NotificationAuthorizationStatus) {
        status = value
    }

    func setGrantOnRequest(_ granted: Bool) {
        grantOnRequest = granted
    }

    func setScheduleError(_ error: Error?) {
        scheduleError = error
    }

    func currentAuthorizationStatus() async -> NotificationAuthorizationStatus {
        authorizationStatusQueryCount += 1
        return status
    }

    func requestAuthorization() async -> Bool {
        authorizationRequestCount += 1
        if grantOnRequest {
            status = .authorized
            return true
        } else {
            status = .denied
            return false
        }
    }

    func scheduleReminder(for item: ItineraryItem) async throws {
        if let scheduleError { throw scheduleError }
        scheduleCalls.append(item)
    }

    func cancelReminder(forItemId itemId: UUID) async {
        itemCancellations.append(itemId)
    }

    func cancelReminders(forTripId tripId: UUID) async {
        tripCancellations.append(tripId)
    }
}
