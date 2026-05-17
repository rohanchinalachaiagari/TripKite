import Foundation

enum NotificationRouteParser {
    static func parse(_ userInfo: [AnyHashable: Any]) -> PendingTripRoute? {
        guard
            let tripIdString = userInfo["tripId"] as? String,
            let tripId = UUID(uuidString: tripIdString)
        else {
            return nil
        }
        let itemId = (userInfo["itemId"] as? String).flatMap(UUID.init(uuidString:))
        return PendingTripRoute(tripId: tripId, itemId: itemId)
    }
}
