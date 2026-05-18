import Foundation
import UserNotifications

// Bridges the UNUserNotificationCenter delegate callback (called on an arbitrary
// queue) to the MainActor-isolated AppRouter. Held strongly by TripKitApp so the
// system's weak delegate reference stays alive for the app's lifetime.
final class NotificationResponseHandler: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    private let router: AppRouter

    init(router: AppRouter) {
        self.router = router
        super.init()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let route = NotificationRouteParser.parse(userInfo) {
            let router = self.router
            Task { @MainActor in
                router.pendingTripDetail = route
            }
        }
        completionHandler()
    }

    // Show banner + sound while the app is foregrounded. Without this, iOS
    // suppresses local notifications when the app is active and the user
    // misses the reminder entirely.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
