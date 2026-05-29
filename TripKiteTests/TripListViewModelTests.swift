import XCTest
@testable import TripKite

@MainActor
final class TripListViewModelTests: XCTestCase {

    func testLoad_PopulatesTripsFromRepository() async {
        let mock = MockTripRepository()
        let trip = makeTrip(title: "Tokyo")
        await mock.seed([trip])

        let viewModel = TripListViewModel(
            repository: mock,
            notificationService: MockNotificationSchedulingService(),
            documentRepository: MockDocumentRepository(),
            documentStorage: MockDocumentStorageService()
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.trips.map(\.id), [trip.id])
        XCTAssertNil(viewModel.errorMessage)
    }

    func testLoad_WhenRepositoryThrows_SetsErrorMessage() async {
        let mock = MockTripRepository()
        struct BoomError: LocalizedError { var errorDescription: String? { "Boom" } }
        await mock.setFetchError(BoomError())

        let viewModel = TripListViewModel(
            repository: mock,
            notificationService: MockNotificationSchedulingService(),
            documentRepository: MockDocumentRepository(),
            documentStorage: MockDocumentStorageService()
        )
        await viewModel.load()

        XCTAssertTrue(viewModel.trips.isEmpty)
        XCTAssertEqual(viewModel.errorMessage, "Boom")
    }

    func testDelete_RemovesTripFromListAndRepository() async {
        let mock = MockTripRepository()
        let kept = makeTrip(title: "Kept")
        let removed = makeTrip(title: "Removed", startOffset: 5)
        await mock.seed([kept, removed])

        let viewModel = TripListViewModel(
            repository: mock,
            notificationService: MockNotificationSchedulingService(),
            documentRepository: MockDocumentRepository(),
            documentStorage: MockDocumentStorageService()
        )
        await viewModel.load()

        await viewModel.delete(removed)

        XCTAssertEqual(viewModel.trips.map(\.id), [kept.id])
        let stored = try? await mock.fetchTrips()
        XCTAssertEqual(stored?.map(\.id), [kept.id])
    }

    func testDelete_CleansUpAllDocumentFilesForTrip() async {
        let mock = MockTripRepository()
        let trip = makeTrip(title: "WithDocs")
        await mock.seed([trip])

        let docRepo = MockDocumentRepository()
        let doc1 = TravelDocument(
            tripId: trip.id,
            fileName: "A.pdf",
            localRelativePath: "Attachments/a.pdf",
            fileType: "pdf"
        )
        let doc2 = TravelDocument(
            tripId: trip.id,
            fileName: "B.pdf",
            localRelativePath: "Attachments/b.pdf",
            fileType: "pdf"
        )
        await docRepo.seed([doc1, doc2])

        let storage = MockDocumentStorageService()
        let viewModel = TripListViewModel(
            repository: mock,
            notificationService: MockNotificationSchedulingService(),
            documentRepository: docRepo,
            documentStorage: storage
        )
        await viewModel.load()

        await viewModel.delete(trip)

        let deletedPaths = await storage.deleteCalls
        XCTAssertEqual(Set(deletedPaths), Set([doc1.localRelativePath, doc2.localRelativePath]))
    }

    func testDelete_CancelsAllRemindersForTrip() async {
        let mock = MockTripRepository()
        let trip = makeTrip(title: "WithItems")
        await mock.seed([trip])
        let notifications = MockNotificationSchedulingService()

        let viewModel = TripListViewModel(
            repository: mock,
            notificationService: notifications,
            documentRepository: MockDocumentRepository(),
            documentStorage: MockDocumentStorageService()
        )
        await viewModel.load()

        await viewModel.delete(trip)

        let tripCancellations = await notifications.tripCancellations
        XCTAssertEqual(tripCancellations, [trip.id])
    }

    func testActiveTrips_OnlyIncludesActiveAndSortsBySoonestEnding() async {
        let now = fixedNow()
        let past = makeTrip(title: "Past", startOffset: -10, endOffset: -5, relativeTo: now)
        let endsLater = makeTrip(title: "EndsLater", startOffset: -1, endOffset: 6, relativeTo: now)
        let endsSooner = makeTrip(title: "EndsSooner", startOffset: -2, endOffset: 2, relativeTo: now)
        let upcoming = makeTrip(title: "Upcoming", startOffset: 3, endOffset: 9, relativeTo: now)

        let mock = MockTripRepository()
        await mock.seed([past, endsLater, endsSooner, upcoming])

        let viewModel = TripListViewModel(
            repository: mock,
            notificationService: MockNotificationSchedulingService(),
            documentRepository: MockDocumentRepository(),
            documentStorage: MockDocumentStorageService(),
            dateProvider: { now }
        )
        await viewModel.load()

        XCTAssertEqual(viewModel.activeTrips.map(\.title), ["EndsSooner", "EndsLater"])
    }

    func testUpcomingTrips_ExcludesActiveAndPast_SortsBySoonestStart() async {
        let now = fixedNow()
        let past = makeTrip(title: "Past", startOffset: -10, endOffset: -5, relativeTo: now)
        let activeNow = makeTrip(title: "Active", startOffset: -1, endOffset: 2, relativeTo: now)
        let soonUpcoming = makeTrip(title: "Soon", startOffset: 3, endOffset: 6, relativeTo: now)
        let laterUpcoming = makeTrip(title: "Later", startOffset: 20, endOffset: 25, relativeTo: now)

        let mock = MockTripRepository()
        await mock.seed([past, activeNow, laterUpcoming, soonUpcoming])

        let viewModel = TripListViewModel(
            repository: mock,
            notificationService: MockNotificationSchedulingService(),
            documentRepository: MockDocumentRepository(),
            documentStorage: MockDocumentStorageService(),
            dateProvider: { now }
        )
        await viewModel.load()

        // Active trips are no longer mixed into "upcoming."
        XCTAssertEqual(viewModel.upcomingTrips.map(\.title), ["Soon", "Later"])
    }

    func testPastTrips_OnlyIncludesPastAndSortsByMostRecentlyEndedFirst() async {
        let now = fixedNow()
        // Trip A ends earlier even though it starts later than Trip B — sort
        // must use endDate, not startDate.
        let endedEarlier = makeTrip(title: "EndedEarlier", startOffset: -8, endOffset: -7, relativeTo: now)
        let endedLater = makeTrip(title: "EndedLater", startOffset: -30, endOffset: -2, relativeTo: now)
        let upcoming = makeTrip(title: "Upcoming", startOffset: 3, endOffset: 6, relativeTo: now)

        let mock = MockTripRepository()
        await mock.seed([endedEarlier, endedLater, upcoming])

        let viewModel = TripListViewModel(
            repository: mock,
            notificationService: MockNotificationSchedulingService(),
            documentRepository: MockDocumentRepository(),
            documentStorage: MockDocumentStorageService(),
            dateProvider: { now }
        )
        await viewModel.load()

        XCTAssertEqual(viewModel.pastTrips.map(\.title), ["EndedLater", "EndedEarlier"])
    }

    func testActiveTrips_WhenNoneActive_ReturnsEmpty() async {
        let now = fixedNow()
        let past = makeTrip(title: "Past", startOffset: -10, endOffset: -5, relativeTo: now)
        let upcoming = makeTrip(title: "Upcoming", startOffset: 5, endOffset: 9, relativeTo: now)

        let mock = MockTripRepository()
        await mock.seed([past, upcoming])

        let viewModel = TripListViewModel(
            repository: mock,
            notificationService: MockNotificationSchedulingService(),
            documentRepository: MockDocumentRepository(),
            documentStorage: MockDocumentStorageService(),
            dateProvider: { now }
        )
        await viewModel.load()

        XCTAssertTrue(viewModel.activeTrips.isEmpty)
        XCTAssertEqual(viewModel.upcomingTrips.map(\.title), ["Upcoming"])
        XCTAssertEqual(viewModel.pastTrips.map(\.title), ["Past"])
    }

    // MARK: - Helpers

    private func fixedNow() -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 1
        return Calendar(identifier: .gregorian).date(from: components) ?? Date()
    }

    private func makeTrip(
        title: String,
        startOffset: Int = 1,
        endOffset: Int? = nil,
        relativeTo reference: Date = Date()
    ) -> Trip {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: startOffset, to: reference) ?? reference
        let end = calendar.date(byAdding: .day, value: endOffset ?? (startOffset + 3), to: reference) ?? start
        return Trip(
            title: title,
            destination: "\(title) City",
            startDate: start,
            endDate: end
        )
    }
}
