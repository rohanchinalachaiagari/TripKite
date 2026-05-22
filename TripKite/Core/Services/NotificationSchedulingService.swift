import Foundation
import UserNotifications

protocol NotificationSchedulingService: Sendable {
    func currentAuthorizationStatus() async -> NotificationAuthorizationStatus
    func requestAuthorization() async -> Bool
    func scheduleReminder(for item: ItineraryItem) async throws
    func cancelReminder(forItemId itemId: UUID) async
    func cancelReminders(forTripId tripId: UUID) async
    // Belt-and-suspenders sweep used by Clear All Data so any pending request
    // whose trip is no longer in Core Data (e.g. orphaned by a prior crash)
    // is still removed.
    func cancelAllReminders() async
}

enum NotificationAuthorizationStatus: Equatable {
    case notDetermined
    case denied
    case authorized
    case provisional
}

enum NotificationSchedulingError: LocalizedError, Equatable {
    case authorizationDenied
    case reminderDateInPast
    case noReminderConfigured

    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "Notifications are turned off for TripKite."
        case .reminderDateInPast:
            return "The reminder time has already passed."
        case .noReminderConfigured:
            return "No reminder is set on this item."
        }
    }
}

// V1 timezone behavior — known limitation:
// Itinerary item dates are interpreted using the device's current timezone when
// entered, and reminder fire times are computed as an absolute offset
// (`item.startDate - reminderOffset`). The notification trigger uses a
// time-interval trigger from now, so iOS records an absolute fire moment that
// does not shift if the user's device timezone changes between scheduling and
// delivery.
//
// Per-itinerary destination timezones are not supported in this milestone. When
// they land, this service should accept (or read from the item) an explicit
// `TimeZone` so the fire time can be anchored to the trip's locale rather than
// the device's. The seam to add is `scheduleReminder(for:)` — the rest of the
// flow (identifiers, cancellation by item or trip) is timezone-agnostic.
nonisolated final class UserNotificationSchedulingService: NotificationSchedulingService, @unchecked Sendable {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func currentAuthorizationStatus() async -> NotificationAuthorizationStatus {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .authorized: return .authorized
        case .provisional: return .provisional
        case .ephemeral: return .authorized
        @unknown default: return .denied
        }
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func scheduleReminder(for item: ItineraryItem) async throws {
        guard let offset = item.reminderOffset else {
            throw NotificationSchedulingError.noReminderConfigured
        }
        let fireDate = item.startDate.addingTimeInterval(-offset)
        let interval = fireDate.timeIntervalSinceNow
        guard interval > 0 else {
            throw NotificationSchedulingError.reminderDateInPast
        }

        let content = UNMutableNotificationContent()
        content.title = "Coming up: \(item.title)"
        content.body = Self.body(for: item)
        content.sound = .default
        content.userInfo = [
            "itemId": item.id.uuidString,
            "tripId": item.tripId.uuidString
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(
            identifier: Self.identifier(forTripId: item.tripId, itemId: item.id),
            content: content,
            trigger: trigger
        )
        try await center.add(request)
    }

    func cancelReminder(forItemId itemId: UUID) async {
        let suffix = "-item-\(itemId.uuidString)"
        let pending = await center.pendingNotificationRequests()
        let matchedIds = pending.map(\.identifier).filter { $0.hasSuffix(suffix) }
        guard !matchedIds.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: matchedIds)
        center.removeDeliveredNotifications(withIdentifiers: matchedIds)
    }

    func cancelReminders(forTripId tripId: UUID) async {
        let prefix = "trip-\(tripId.uuidString)-"
        let pending = await center.pendingNotificationRequests()
        let matchedIds = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        guard !matchedIds.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: matchedIds)
        center.removeDeliveredNotifications(withIdentifiers: matchedIds)
    }

    func cancelAllReminders() async {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    private static func identifier(forTripId tripId: UUID, itemId: UUID) -> String {
        "trip-\(tripId.uuidString)-item-\(itemId.uuidString)"
    }

    private static func body(for item: ItineraryItem) -> String {
        var parts: [String] = [TripDateFormatter.timeRange(start: item.startDate, end: item.endDate)]
        if !item.locationName.isEmpty {
            parts.append(item.locationName)
        }
        return parts.joined(separator: " · ")
    }
}
