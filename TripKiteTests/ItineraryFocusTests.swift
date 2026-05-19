import XCTest
@testable import TripKite

final class ItineraryFocusTests: XCTestCase {

    // MARK: - Empty / past

    func testResolve_WhenEmpty_ReturnsNil() {
        let result = ItineraryFocusResolver.resolve(items: [], now: fixedNow())
        XCTAssertNil(result)
    }

    func testResolve_WhenAllItemsPast_ReturnsNil() {
        let now = fixedNow()
        let past = makeItem(
            title: "Past",
            start: now.addingTimeInterval(-3 * 3600),
            end: now.addingTimeInterval(-2 * 3600)
        )
        let result = ItineraryFocusResolver.resolve(items: [past], now: now)
        XCTAssertNil(result)
    }

    // MARK: - Happening Now

    func testResolve_WhenSingleActiveItem_ReturnsHappeningNow() {
        let now = fixedNow()
        let active = makeItem(
            title: "Tour",
            start: now.addingTimeInterval(-30 * 60),
            end: now.addingTimeInterval(60 * 60)
        )
        let result = ItineraryFocusResolver.resolve(items: [active], now: now)
        XCTAssertEqual(result, .happeningNow(active))
    }

    func testResolve_WhenActiveAndUpcomingCoexist_PrefersHappeningNow() {
        let now = fixedNow()
        let active = makeItem(
            title: "Now",
            start: now.addingTimeInterval(-30 * 60),
            end: now.addingTimeInterval(60 * 60)
        )
        let upcoming = makeItem(
            title: "Later",
            start: now.addingTimeInterval(2 * 3600)
        )
        let result = ItineraryFocusResolver.resolve(items: [active, upcoming], now: now)
        XCTAssertEqual(result, .happeningNow(active))
    }

    func testResolve_WhenMultipleActiveOverlap_PrefersMostRecentlyStarted() {
        let now = fixedNow()
        let hotel = makeItem(
            title: "Hotel",
            start: now.addingTimeInterval(-24 * 3600),
            end: now.addingTimeInterval(3600)
        )
        let dinner = makeItem(
            title: "Dinner",
            start: now.addingTimeInterval(-30 * 60),
            end: now.addingTimeInterval(60 * 60)
        )
        let result = ItineraryFocusResolver.resolve(items: [hotel, dinner], now: now)
        XCTAssertEqual(result, .happeningNow(dinner))
    }

    // MARK: - Up Next

    func testResolve_WhenNoActiveButMultipleUpcoming_ReturnsClosestUpcomingAsUpNext() {
        let now = fixedNow()
        let near = makeItem(title: "Near", start: now.addingTimeInterval(3600))
        let far = makeItem(title: "Far", start: now.addingTimeInterval(2 * 3600))
        let result = ItineraryFocusResolver.resolve(items: [far, near], now: now)
        XCTAssertEqual(result, .upNext(near))
    }

    // MARK: - Point items (no endDate)

    func testResolve_PointItem_IsActiveWithinDefaultDuration() {
        let now = fixedNow()
        let point = makeItem(title: "Note", start: now.addingTimeInterval(-30 * 60))
        let result = ItineraryFocusResolver.resolve(items: [point], now: now)
        XCTAssertEqual(result, .happeningNow(point))
    }

    func testResolve_PointItem_BeyondDefaultDuration_IsNotActive() {
        let now = fixedNow()
        let point = makeItem(title: "Note", start: now.addingTimeInterval(-3 * 3600))
        let result = ItineraryFocusResolver.resolve(items: [point], now: now)
        XCTAssertNil(result)
    }

    func testResolve_RespectsCustomPointDuration() {
        let now = fixedNow()
        let point = makeItem(title: "Quick", start: now.addingTimeInterval(-45 * 60))
        let result = ItineraryFocusResolver.resolve(
            items: [point],
            now: now,
            pointDuration: 30 * 60
        )
        XCTAssertNil(result)
    }

    // MARK: - Tie-breaking

    func testResolve_TieOnStartDate_BrokenByCreatedAtAscending() {
        let now = fixedNow()
        let start = now.addingTimeInterval(3600)
        let earlyCreated = ItineraryItem(
            tripId: UUID(),
            title: "Early-created",
            type: .activity,
            startDate: start,
            createdAt: Date(timeIntervalSince1970: 100)
        )
        let lateCreated = ItineraryItem(
            tripId: UUID(),
            title: "Late-created",
            type: .activity,
            startDate: start,
            createdAt: Date(timeIntervalSince1970: 200)
        )
        let result = ItineraryFocusResolver.resolve(items: [lateCreated, earlyCreated], now: now)
        XCTAssertEqual(result, .upNext(earlyCreated))
    }

    // MARK: - Helpers

    private func fixedNow() -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 17
        components.hour = 12
        return Calendar(identifier: .gregorian).date(from: components) ?? Date()
    }

    private func makeItem(
        title: String,
        start: Date,
        end: Date? = nil
    ) -> ItineraryItem {
        ItineraryItem(
            tripId: UUID(),
            title: title,
            type: .activity,
            startDate: start,
            endDate: end,
            createdAt: Date(timeIntervalSince1970: 0)
        )
    }
}
