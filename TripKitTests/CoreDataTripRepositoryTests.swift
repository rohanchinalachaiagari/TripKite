import XCTest
@testable import TripKit

final class CoreDataTripRepositoryTests: XCTestCase {
    private var stack: CoreDataStack!
    private var repository: CoreDataTripRepository!

    override func setUp() {
        super.setUp()
        stack = CoreDataStack(inMemory: true)
        repository = CoreDataTripRepository(stack: stack)
    }

    override func tearDown() {
        repository = nil
        stack = nil
        super.tearDown()
    }

    // MARK: - Fetch

    func testFetchTrips_WhenEmpty_ReturnsEmptyArray() async throws {
        let trips = try await repository.fetchTrips()
        XCTAssertTrue(trips.isEmpty)
    }

    func testFetchTrips_SortsByStartDateAscending() async throws {
        let later = makeTrip(title: "Later", startOffset: 30)
        let earlier = makeTrip(title: "Earlier", startOffset: 1)
        let middle = makeTrip(title: "Middle", startOffset: 15)

        try await repository.createTrip(later)
        try await repository.createTrip(earlier)
        try await repository.createTrip(middle)

        let trips = try await repository.fetchTrips()

        XCTAssertEqual(trips.map(\.title), ["Earlier", "Middle", "Later"])
    }

    // MARK: - Create

    func testCreateTrip_ThenFetch_ReturnsTrip() async throws {
        let trip = makeTrip(title: "Tokyo")
        try await repository.createTrip(trip)

        let trips = try await repository.fetchTrips()

        XCTAssertEqual(trips.count, 1)
        XCTAssertEqual(trips.first?.id, trip.id)
        XCTAssertEqual(trips.first?.title, "Tokyo")
        XCTAssertEqual(trips.first?.destination, trip.destination)
    }

    func testTripWithId_ReturnsMatchingTrip() async throws {
        let trip = makeTrip(title: "Lisbon")
        try await repository.createTrip(trip)

        let fetched = try await repository.trip(with: trip.id)

        XCTAssertEqual(fetched?.id, trip.id)
        XCTAssertEqual(fetched?.title, "Lisbon")
    }

    func testTripWithId_WhenMissing_ReturnsNil() async throws {
        let fetched = try await repository.trip(with: UUID())
        XCTAssertNil(fetched)
    }

    // MARK: - Update

    func testUpdateTrip_PersistsChanges() async throws {
        var trip = makeTrip(title: "Original")
        try await repository.createTrip(trip)

        trip.title = "Updated"
        trip.notes = "New notes"
        try await repository.updateTrip(trip)

        let fetched = try await repository.trip(with: trip.id)
        XCTAssertEqual(fetched?.title, "Updated")
        XCTAssertEqual(fetched?.notes, "New notes")
    }

    func testUpdateTrip_WhenTripDoesNotExist_ThrowsNotFound() async {
        let trip = makeTrip(title: "Ghost")
        do {
            try await repository.updateTrip(trip)
            XCTFail("Expected updateTrip to throw")
        } catch let error as TripRepositoryError {
            XCTAssertEqual(error, .notFound)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Delete

    func testDeleteTrip_RemovesTrip() async throws {
        let trip = makeTrip(title: "To delete")
        try await repository.createTrip(trip)

        try await repository.deleteTrip(id: trip.id)

        let trips = try await repository.fetchTrips()
        XCTAssertTrue(trips.isEmpty)
    }

    func testDeleteTrip_WhenTripDoesNotExist_DoesNotThrow() async throws {
        try await repository.deleteTrip(id: UUID())
    }

    func testDeleteTrip_PreservesOtherTrips() async throws {
        let keep = makeTrip(title: "Keep")
        let drop = makeTrip(title: "Drop", startOffset: 5)
        try await repository.createTrip(keep)
        try await repository.createTrip(drop)

        try await repository.deleteTrip(id: drop.id)

        let trips = try await repository.fetchTrips()
        XCTAssertEqual(trips.map(\.title), ["Keep"])
    }

    // MARK: - Helpers

    private func makeTrip(
        title: String,
        startOffset: Int = 1
    ) -> Trip {
        let start = Calendar.current.date(byAdding: .day, value: startOffset, to: Date()) ?? Date()
        let end = Calendar.current.date(byAdding: .day, value: startOffset + 3, to: Date()) ?? start
        return Trip(
            title: title,
            destination: "\(title) City",
            startDate: start,
            endDate: end,
            notes: ""
        )
    }
}
