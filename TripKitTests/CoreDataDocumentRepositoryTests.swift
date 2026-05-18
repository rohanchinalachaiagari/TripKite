import XCTest
@testable import TripKit

final class CoreDataDocumentRepositoryTests: XCTestCase {
    private var stack: CoreDataStack!
    private var tripRepository: CoreDataTripRepository!
    private var itineraryRepository: CoreDataItineraryRepository!
    private var repository: CoreDataDocumentRepository!
    private var trip: Trip!
    private var otherTrip: Trip!

    override func setUp() async throws {
        try await super.setUp()
        stack = CoreDataStack(inMemory: true)
        tripRepository = CoreDataTripRepository(stack: stack)
        itineraryRepository = CoreDataItineraryRepository(stack: stack)
        repository = CoreDataDocumentRepository(stack: stack)

        trip = makeTrip(title: "Main")
        otherTrip = makeTrip(title: "Other", startOffset: 10)
        try await tripRepository.createTrip(trip)
        try await tripRepository.createTrip(otherTrip)
    }

    override func tearDown() {
        repository = nil
        itineraryRepository = nil
        tripRepository = nil
        stack = nil
        trip = nil
        otherTrip = nil
        super.tearDown()
    }

    // MARK: - Fetch

    func testFetchDocuments_WhenEmpty_ReturnsEmpty() async throws {
        let docs = try await repository.fetchDocuments(for: trip.id)
        XCTAssertTrue(docs.isEmpty)
    }

    func testFetchDocuments_FiltersToTripAndSortsByCreatedAtAscending() async throws {
        let early = makeDocument(name: "Early", tripId: trip.id, createdAt: Date(timeIntervalSince1970: 100))
        let late = makeDocument(name: "Late", tripId: trip.id, createdAt: Date(timeIntervalSince1970: 200))
        let foreign = makeDocument(name: "Foreign", tripId: otherTrip.id, createdAt: Date(timeIntervalSince1970: 150))
        try await repository.createDocument(late)
        try await repository.createDocument(foreign)
        try await repository.createDocument(early)

        let docs = try await repository.fetchDocuments(for: trip.id)

        XCTAssertEqual(docs.map(\.fileName), ["Early", "Late"])
    }

    // MARK: - Create

    func testCreateDocument_AttachesToCorrectTrip() async throws {
        let doc = makeDocument(name: "Confirmation.pdf", tripId: trip.id)
        try await repository.createDocument(doc)

        let fetched = try await repository.document(with: doc.id)
        XCTAssertEqual(fetched?.tripId, trip.id)
        XCTAssertEqual(fetched?.fileName, "Confirmation.pdf")
    }

    func testCreateDocument_WhenTripMissing_ThrowsTripNotFound() async {
        let doc = makeDocument(name: "Orphan", tripId: UUID())
        do {
            try await repository.createDocument(doc)
            XCTFail("Expected createDocument to throw")
        } catch let error as DocumentRepositoryError {
            XCTAssertEqual(error, .tripNotFound)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCreateDocument_WhenItemMissing_ThrowsItemNotFound() async throws {
        var doc = makeDocument(name: "ItemDoc", tripId: trip.id)
        doc.itineraryItemId = UUID()
        do {
            try await repository.createDocument(doc)
            XCTFail("Expected createDocument to throw")
        } catch let error as DocumentRepositoryError {
            XCTAssertEqual(error, .itemNotFound)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Update

    func testUpdateDocument_PersistsRenamedFileName() async throws {
        var doc = makeDocument(name: "Original.pdf", tripId: trip.id)
        try await repository.createDocument(doc)

        doc.fileName = "Hotel confirmation.pdf"
        try await repository.updateDocument(doc)

        let fetched = try await repository.document(with: doc.id)
        XCTAssertEqual(fetched?.fileName, "Hotel confirmation.pdf")
        XCTAssertEqual(fetched?.localRelativePath, doc.localRelativePath)
    }

    func testUpdateDocument_AssigningToItem_PersistsRelationship() async throws {
        let item = ItineraryItem(
            tripId: trip.id,
            title: "Flight",
            type: .flight,
            startDate: Date()
        )
        try await itineraryRepository.createItem(item)

        var doc = makeDocument(name: "Boarding pass", tripId: trip.id)
        try await repository.createDocument(doc)

        doc.itineraryItemId = item.id
        try await repository.updateDocument(doc)

        let fetched = try await repository.document(with: doc.id)
        XCTAssertEqual(fetched?.itineraryItemId, item.id)

        let byItem = try await repository.fetchDocuments(forItemId: item.id)
        XCTAssertEqual(byItem.map(\.id), [doc.id])
    }

    func testUpdateDocument_ClearingItem_RemovesRelationship() async throws {
        let item = ItineraryItem(
            tripId: trip.id,
            title: "Hotel",
            type: .hotel,
            startDate: Date()
        )
        try await itineraryRepository.createItem(item)

        var doc = makeDocument(name: "Confirmation", tripId: trip.id)
        doc.itineraryItemId = item.id
        try await repository.createDocument(doc)

        doc.itineraryItemId = nil
        try await repository.updateDocument(doc)

        let fetched = try await repository.document(with: doc.id)
        XCTAssertNil(fetched?.itineraryItemId)

        let byItem = try await repository.fetchDocuments(forItemId: item.id)
        XCTAssertTrue(byItem.isEmpty)

        let byTrip = try await repository.fetchDocuments(for: trip.id)
        XCTAssertEqual(byTrip.map(\.id), [doc.id], "Document should still belong to the trip")
    }

    func testUpdateDocument_WhenNewItemMissing_ThrowsItemNotFound() async throws {
        var doc = makeDocument(name: "Floating", tripId: trip.id)
        try await repository.createDocument(doc)

        doc.itineraryItemId = UUID()
        do {
            try await repository.updateDocument(doc)
            XCTFail("Expected updateDocument to throw itemNotFound")
        } catch let error as DocumentRepositoryError {
            XCTAssertEqual(error, .itemNotFound)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testUpdateDocument_WhenMissing_ThrowsNotFound() async {
        let doc = makeDocument(name: "Ghost", tripId: trip.id)
        do {
            try await repository.updateDocument(doc)
            XCTFail("Expected updateDocument to throw")
        } catch let error as DocumentRepositoryError {
            XCTAssertEqual(error, .notFound)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Delete

    func testDeleteDocument_RemovesRecord() async throws {
        let doc = makeDocument(name: "Delete me", tripId: trip.id)
        try await repository.createDocument(doc)

        try await repository.deleteDocument(id: doc.id)

        let fetched = try await repository.document(with: doc.id)
        XCTAssertNil(fetched)
    }

    func testDeleteDocument_WhenMissing_DoesNotThrow() async throws {
        try await repository.deleteDocument(id: UUID())
    }

    // MARK: - Cascade

    func testDeleteTrip_CascadesDocumentRecords() async throws {
        let doc = makeDocument(name: "Child", tripId: trip.id)
        try await repository.createDocument(doc)

        try await tripRepository.deleteTrip(id: trip.id)

        let direct = try await repository.document(with: doc.id)
        XCTAssertNil(direct)
    }

    func testDeleteItem_PreservesDocument_NullifiesItemRelationship() async throws {
        let item = ItineraryItem(
            tripId: trip.id,
            title: "Flight",
            type: .flight,
            startDate: Date()
        )
        try await itineraryRepository.createItem(item)

        var doc = makeDocument(name: "Boarding pass", tripId: trip.id)
        doc.itineraryItemId = item.id
        try await repository.createDocument(doc)

        try await itineraryRepository.deleteItem(id: item.id)

        let fetched = try await repository.document(with: doc.id)
        XCTAssertNotNil(fetched, "Document should survive item deletion")
        XCTAssertNil(fetched?.itineraryItemId, "Item relationship should be nullified")
    }

    // MARK: - Helpers

    private func makeTrip(title: String, startOffset: Int = 1) -> Trip {
        let start = Calendar.current.date(byAdding: .day, value: startOffset, to: Date()) ?? Date()
        let end = Calendar.current.date(byAdding: .day, value: startOffset + 3, to: Date()) ?? start
        return Trip(title: title, destination: "\(title) City", startDate: start, endDate: end)
    }

    private func makeDocument(
        name: String,
        tripId: UUID,
        createdAt: Date = Date()
    ) -> TravelDocument {
        TravelDocument(
            tripId: tripId,
            fileName: name,
            localRelativePath: "Attachments/\(UUID().uuidString).pdf",
            fileType: "pdf",
            fileSize: 2048,
            createdAt: createdAt
        )
    }
}
