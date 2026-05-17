import XCTest
@testable import TripKit

final class CoreDataItineraryRepositoryTests: XCTestCase {
    private var stack: CoreDataStack!
    private var tripRepository: CoreDataTripRepository!
    private var repository: CoreDataItineraryRepository!
    private var trip: Trip!
    private var otherTrip: Trip!

    override func setUp() async throws {
        try await super.setUp()
        stack = CoreDataStack(inMemory: true)
        tripRepository = CoreDataTripRepository(stack: stack)
        repository = CoreDataItineraryRepository(stack: stack)
        trip = makeTrip(title: "Main")
        otherTrip = makeTrip(title: "Other", startOffset: 10)
        try await tripRepository.createTrip(trip)
        try await tripRepository.createTrip(otherTrip)
    }

    override func tearDown() {
        repository = nil
        tripRepository = nil
        stack = nil
        trip = nil
        otherTrip = nil
        super.tearDown()
    }

    // MARK: - Fetch

    func testFetchItems_WhenEmpty_ReturnsEmpty() async throws {
        let items = try await repository.fetchItems(for: trip.id)
        XCTAssertTrue(items.isEmpty)
    }

    func testFetchItems_OnlyReturnsItemsForRequestedTrip() async throws {
        let mine = makeItem(title: "Mine", tripId: trip.id)
        let theirs = makeItem(title: "Theirs", tripId: otherTrip.id)
        try await repository.createItem(mine)
        try await repository.createItem(theirs)

        let items = try await repository.fetchItems(for: trip.id)

        XCTAssertEqual(items.map(\.title), ["Mine"])
    }

    func testFetchItems_SortsByStartDateAscending() async throws {
        let later = makeItem(title: "Later", tripId: trip.id, startOffsetHours: 48)
        let earlier = makeItem(title: "Earlier", tripId: trip.id, startOffsetHours: 1)
        let middle = makeItem(title: "Middle", tripId: trip.id, startOffsetHours: 24)
        try await repository.createItem(later)
        try await repository.createItem(earlier)
        try await repository.createItem(middle)

        let items = try await repository.fetchItems(for: trip.id)

        XCTAssertEqual(items.map(\.title), ["Earlier", "Middle", "Later"])
    }

    // MARK: - Create

    func testCreateItem_AttachesToCorrectTrip() async throws {
        let item = makeItem(title: "Flight", tripId: trip.id)
        try await repository.createItem(item)

        let fetched = try await repository.item(with: item.id)
        XCTAssertEqual(fetched?.tripId, trip.id)
        XCTAssertEqual(fetched?.title, "Flight")
    }

    func testCreateItem_WhenTripDoesNotExist_ThrowsTripNotFound() async {
        let orphan = makeItem(title: "Orphan", tripId: UUID())
        do {
            try await repository.createItem(orphan)
            XCTFail("Expected createItem to throw")
        } catch let error as ItineraryRepositoryError {
            XCTAssertEqual(error, .tripNotFound)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Update

    func testUpdateItem_PersistsChanges() async throws {
        var item = makeItem(title: "Original", tripId: trip.id)
        try await repository.createItem(item)

        item.title = "Updated"
        item.notes = "New notes"
        try await repository.updateItem(item)

        let fetched = try await repository.item(with: item.id)
        XCTAssertEqual(fetched?.title, "Updated")
        XCTAssertEqual(fetched?.notes, "New notes")
    }

    func testUpdateItem_WhenMissing_ThrowsNotFound() async {
        let ghost = makeItem(title: "Ghost", tripId: trip.id)
        do {
            try await repository.updateItem(ghost)
            XCTFail("Expected updateItem to throw")
        } catch let error as ItineraryRepositoryError {
            XCTAssertEqual(error, .notFound)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Delete

    func testDeleteItem_RemovesItem() async throws {
        let item = makeItem(title: "Delete me", tripId: trip.id)
        try await repository.createItem(item)

        try await repository.deleteItem(id: item.id)

        let fetched = try await repository.item(with: item.id)
        XCTAssertNil(fetched)
    }

    func testDeleteItem_WhenMissing_DoesNotThrow() async throws {
        try await repository.deleteItem(id: UUID())
    }

    // MARK: - Cascade

    func testDeleteTrip_CascadesDeletesItems() async throws {
        let item = makeItem(title: "Child", tripId: trip.id)
        try await repository.createItem(item)

        try await tripRepository.deleteTrip(id: trip.id)

        let items = try await repository.fetchItems(for: trip.id)
        XCTAssertTrue(items.isEmpty)
        let direct = try await repository.item(with: item.id)
        XCTAssertNil(direct)
    }

    // MARK: - Helpers

    private func makeTrip(title: String, startOffset: Int = 1) -> Trip {
        let start = Calendar.current.date(byAdding: .day, value: startOffset, to: Date()) ?? Date()
        let end = Calendar.current.date(byAdding: .day, value: startOffset + 3, to: Date()) ?? start
        return Trip(title: title, destination: "\(title) City", startDate: start, endDate: end)
    }

    private func makeItem(
        title: String,
        tripId: UUID,
        startOffsetHours: Int = 1
    ) -> ItineraryItem {
        let start = Calendar.current.date(byAdding: .hour, value: startOffsetHours, to: Date()) ?? Date()
        return ItineraryItem(
            tripId: tripId,
            title: title,
            type: .activity,
            startDate: start
        )
    }
}
