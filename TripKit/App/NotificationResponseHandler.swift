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
}
