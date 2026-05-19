import XCTest
@testable import TripKite

@MainActor
final class AppRouterTests: XCTestCase {

    func testInitial_PendingRouteIsNil() {
        let router = AppRouter()
        XCTAssertNil(router.pendingTripDetail)
    }

    func testSetAndClear_PendingRoute() {
        let router = AppRouter()
        let route = PendingTripRoute(tripId: UUID(), itemId: nil)

        router.pendingTripDetail = route
        XCTAssertEqual(router.pendingTripDetail, route)

        router.pendingTripDetail = nil
        XCTAssertNil(router.pendingTripDetail)
    }

    func testReplace_OverwritesPreviousPendingRoute() {
        let router = AppRouter()
        let first = PendingTripRoute(tripId: UUID(), itemId: nil)
        let second = PendingTripRoute(tripId: UUID(), itemId: UUID())

        router.pendingTripDetail = first
        router.pendingTripDetail = second

        XCTAssertEqual(router.pendingTripDetail, second)
    }
}
