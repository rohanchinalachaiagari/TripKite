import XCTest
@testable import TripKite

@MainActor
final class DocumentVaultViewModelTests: XCTestCase {

    // MARK: - Load

    func testLoad_PopulatesDocumentsTripsAndItemsByTrip() async {
        let tripA = makeTrip(title: "Tokyo")
        let tripB = makeTrip(title: "Lisbon", startOffset: 5)
        let item = ItineraryItem(tripId: tripA.id, title: "Flight", type: .flight, startDate: Date())
        let doc = TravelDocument(
            tripId: tripA.id,
            fileName: "Boarding.pdf",
            localRelativePath: "Attachments/x.pdf",
            fileType: "pdf"
        )

        let trips = MockTripRepository()
        await trips.seed([tripA, tripB])
        let itinerary = MockItineraryRepository()
        await itinerary.seed([item])
        let docs = MockDocumentRepository()
        await docs.seed([doc])
        let storage = MockDocumentStorageService()

        let vm = makeViewModel(docs: docs, trips: trips, itinerary: itinerary, storage: storage)
        await vm.load()

        XCTAssertEqual(vm.documents.map(\.id), [doc.id])
        XCTAssertEqual(Set(vm.trips.map(\.id)), Set([tripA.id, tripB.id]))
        XCTAssertEqual(vm.itemsByTripId[tripA.id]?.map(\.id), [item.id])
        XCTAssertNil(vm.errorMessage)
    }

    func testLoad_WhenDocumentFetchFails_SetsErrorMessage() async {
        let docs = MockDocumentRepository()
        struct BoomError: LocalizedError { var errorDescription: String? { "Boom" } }
        await docs.setFetchError(BoomError())

        let vm = makeViewModel(docs: docs)
        await vm.load()

        XCTAssertTrue(vm.documents.isEmpty)
        XCTAssertEqual(vm.errorMessage, "Boom")
    }

    // MARK: - Stage photo

    func testStagePhoto_DetectsPNGAndWritesTemp_SetsPendingImport() throws {
        let vm = makeViewModel()
        let pngHeader = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        let payload = pngHeader + Data(repeating: 0xFF, count: 256)

        vm.stagePhoto(data: payload, capturedAt: Date(timeIntervalSince1970: 1_700_000_000))

        let pending = try XCTUnwrap(vm.pendingImport)
        XCTAssertEqual(pending.fileType, "png")
        XCTAssertTrue(pending.suggestedFileName.hasPrefix("Screenshot-"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: pending.url.path))

        // Clean up the temp file the test wrote.
        try? FileManager.default.removeItem(at: pending.url)
    }

    func testStagePhoto_UnknownBytesFallBackToJPEG() throws {
        let vm = makeViewModel()
        let payload = Data(repeating: 0x00, count: 64)

        vm.stagePhoto(data: payload, capturedAt: Date(timeIntervalSince1970: 1_700_000_000))

        let pending = try XCTUnwrap(vm.pendingImport)
        XCTAssertEqual(pending.fileType, "jpg")
        XCTAssertTrue(pending.suggestedFileName.hasPrefix("Photo-"))
        try? FileManager.default.removeItem(at: pending.url)
    }

    // MARK: - Confirm import

    func testConfirmImport_WithTripOnly_PersistsWithoutItemId() async throws {
        let trip = makeTrip(title: "Tokyo")
        let env = await makeImportEnv(seedingTrip: trip)
        env.vm.stagePhoto(data: jpegPayload(), capturedAt: Date(timeIntervalSince1970: 1_700_000_000))

        await env.vm.confirmImport(tripId: trip.id, itemId: nil)

        let stored = await env.documents.storage.values.first
        XCTAssertEqual(stored?.tripId, trip.id)
        XCTAssertNil(stored?.itineraryItemId)
        XCTAssertNil(env.vm.pendingImport)
        XCTAssertEqual(env.vm.documents.count, 1)
        XCTAssertNil(env.vm.errorMessage)
    }

    func testConfirmImport_WithItem_PersistsAssociation() async throws {
        let trip = makeTrip(title: "Tokyo")
        let item = ItineraryItem(tripId: trip.id, title: "Flight", type: .flight, startDate: Date())
        let env = await makeImportEnv(seedingTrip: trip, seedingItem: item)
        env.vm.stagePhoto(data: jpegPayload(), capturedAt: Date(timeIntervalSince1970: 1_700_000_000))

        await env.vm.confirmImport(tripId: trip.id, itemId: item.id)

        let stored = await env.documents.storage.values.first
        XCTAssertEqual(stored?.itineraryItemId, item.id)
    }

    func testConfirmImport_AppendsToInMemoryListAndSortsByCreatedAtDescending() async throws {
        let trip = makeTrip(title: "Tokyo")
        let older = TravelDocument(
            tripId: trip.id,
            fileName: "Older",
            localRelativePath: "Attachments/old.pdf",
            fileType: "pdf",
            createdAt: Date(timeIntervalSince1970: 1_600_000_000)
        )
        let env = await makeImportEnv(seedingTrip: trip, seedingDocuments: [older])
        await env.vm.load()
        env.vm.stagePhoto(data: jpegPayload(), capturedAt: Date(timeIntervalSince1970: 1_800_000_000))

        await env.vm.confirmImport(tripId: trip.id, itemId: nil)

        XCTAssertEqual(env.vm.documents.count, 2)
        XCTAssertEqual(env.vm.documents.first?.createdAt.timeIntervalSinceReferenceDate ?? 0,
                       Date(timeIntervalSince1970: 1_800_000_000).timeIntervalSinceReferenceDate,
                       accuracy: 1.0,
                       "Newest document should be first")
    }

    func testConfirmImport_WhenStorageFails_LeavesPendingForRetry() async throws {
        let trip = makeTrip(title: "Tokyo")
        let env = await makeImportEnv(seedingTrip: trip)
        struct BoomError: LocalizedError { var errorDescription: String? { "Storage down" } }
        await env.storage.setSaveError(BoomError())
        env.vm.stagePhoto(data: jpegPayload(), capturedAt: Date(timeIntervalSince1970: 1_700_000_000))
        let stagedURL = env.vm.pendingImport?.url

        await env.vm.confirmImport(tripId: trip.id, itemId: nil)

        XCTAssertEqual(env.vm.errorMessage, "Storage down")
        XCTAssertNotNil(env.vm.pendingImport, "User should be able to retry; pending stays set")
        let createCount = await env.documents.createCallCount
        XCTAssertEqual(createCount, 0)
        try? FileManager.default.removeItem(at: stagedURL!)
    }

    func testConfirmImport_WhenRepositoryFails_RollsBackFileAndSetsError() async throws {
        let trip = makeTrip(title: "Tokyo")
        let env = await makeImportEnv(seedingTrip: trip)
        struct BoomError: LocalizedError { var errorDescription: String? { "DB down" } }
        await env.documents.setCreateError(BoomError())
        env.vm.stagePhoto(data: jpegPayload(), capturedAt: Date(timeIntervalSince1970: 1_700_000_000))

        await env.vm.confirmImport(tripId: trip.id, itemId: nil)

        let deleteCalls = await env.storage.deleteCalls
        XCTAssertEqual(deleteCalls.count, 1, "File should be rolled back after metadata failure")
        XCTAssertEqual(env.vm.errorMessage, "DB down")
        XCTAssertTrue(env.vm.documents.isEmpty)
        XCTAssertNil(env.vm.pendingImport, "Pending is cleared even on metadata failure")
    }

    func testCancelImport_RemovesTempFileAndClearsPending() throws {
        let vm = makeViewModel()
        vm.stagePhoto(data: jpegPayload(), capturedAt: Date(timeIntervalSince1970: 1_700_000_000))
        let pending = try XCTUnwrap(vm.pendingImport)
        XCTAssertTrue(FileManager.default.fileExists(atPath: pending.url.path))

        vm.cancelImport()

        XCTAssertNil(vm.pendingImport)
        XCTAssertFalse(FileManager.default.fileExists(atPath: pending.url.path))
    }

    // MARK: - Rename

    func testRename_PreservesPathAndType() async {
        let doc = TravelDocument(
            tripId: UUID(),
            fileName: "Original",
            localRelativePath: "Attachments/stable.png",
            fileType: "png"
        )
        let docs = MockDocumentRepository()
        await docs.seed([doc])
        let vm = makeViewModel(docs: docs)
        await vm.load()

        await vm.renameDocument(doc, to: "Renamed.png")

        let stored = await docs.storage[doc.id]
        XCTAssertEqual(stored?.fileName, "Renamed")
        XCTAssertEqual(stored?.fileType, "png")
        XCTAssertEqual(stored?.localRelativePath, "Attachments/stable.png")
    }

    func testRename_EmptyAfterTrim_IsRejectedAndDoesNotPersist() async {
        let doc = TravelDocument(
            tripId: UUID(),
            fileName: "Original",
            localRelativePath: "Attachments/x.pdf",
            fileType: "pdf"
        )
        let docs = MockDocumentRepository()
        await docs.seed([doc])
        let vm = makeViewModel(docs: docs)
        await vm.load()

        await vm.renameDocument(doc, to: "   ")

        let updateCount = await docs.updateCallCount
        XCTAssertEqual(updateCount, 0)
        XCTAssertNotNil(vm.errorMessage)
    }

    // MARK: - Set association

    func testSetAssociation_AssignToItem() async {
        let trip = makeTrip(title: "Tokyo")
        let item = ItineraryItem(tripId: trip.id, title: "Flight", type: .flight, startDate: Date())
        let doc = TravelDocument(
            tripId: trip.id,
            fileName: "Boarding",
            localRelativePath: "Attachments/x.pdf",
            fileType: "pdf"
        )
        let docs = MockDocumentRepository()
        await docs.seed([doc])
        await docs.seedItemIds([item.id])
        let trips = MockTripRepository()
        await trips.seed([trip])
        let itinerary = MockItineraryRepository()
        await itinerary.seed([item])
        let vm = makeViewModel(docs: docs, trips: trips, itinerary: itinerary)
        await vm.load()

        await vm.setAssociation(for: doc, itineraryItemId: item.id)

        XCTAssertEqual(vm.documents.first?.itineraryItemId, item.id)
        let stored = await docs.storage[doc.id]
        XCTAssertEqual(stored?.itineraryItemId, item.id)
    }

    func testSetAssociation_ClearToTripLevel() async {
        let trip = makeTrip(title: "Tokyo")
        let item = ItineraryItem(tripId: trip.id, title: "Flight", type: .flight, startDate: Date())
        let doc = TravelDocument(
            tripId: trip.id,
            itineraryItemId: item.id,
            fileName: "Boarding",
            localRelativePath: "Attachments/x.pdf",
            fileType: "pdf"
        )
        let docs = MockDocumentRepository()
        await docs.seed([doc])
        let vm = makeViewModel(docs: docs)
        await vm.load()

        await vm.setAssociation(for: doc, itineraryItemId: nil)

        XCTAssertNil(vm.documents.first?.itineraryItemId)
    }

    // MARK: - Delete

    func testDelete_RemovesRecordThenFile() async {
        let doc = TravelDocument(
            tripId: UUID(),
            fileName: "Doomed",
            localRelativePath: "Attachments/doomed.pdf",
            fileType: "pdf"
        )
        let docs = MockDocumentRepository()
        await docs.seed([doc])
        let storage = MockDocumentStorageService()
        let vm = makeViewModel(docs: docs, storage: storage)
        await vm.load()

        await vm.delete(doc)

        let deleteCount = await docs.deleteCallCount
        let storageDeleteCalls = await storage.deleteCalls
        XCTAssertEqual(deleteCount, 1)
        XCTAssertEqual(storageDeleteCalls, [doc.localRelativePath])
        XCTAssertTrue(vm.documents.isEmpty)
    }

    func testDelete_WhenRepoFails_DoesNotDeleteFile() async {
        let doc = TravelDocument(
            tripId: UUID(),
            fileName: "Stuck",
            localRelativePath: "Attachments/stuck.pdf",
            fileType: "pdf"
        )
        let docs = MockDocumentRepository()
        await docs.seed([doc])
        struct BoomError: LocalizedError { var errorDescription: String? { "Nope" } }
        await docs.setDeleteError(BoomError())
        let storage = MockDocumentStorageService()
        let vm = makeViewModel(docs: docs, storage: storage)
        await vm.load()

        await vm.delete(doc)

        let storageDeleteCalls = await storage.deleteCalls
        XCTAssertTrue(storageDeleteCalls.isEmpty)
        XCTAssertEqual(vm.documents.count, 1)
        XCTAssertEqual(vm.errorMessage, "Nope")
    }

    // MARK: - Grouping

    func testGroupedDocuments_OrdersTripsByStartDateAndOmitsEmptyTrips() async {
        let early = makeTrip(title: "Lisbon", startOffset: 1)
        let later = makeTrip(title: "Tokyo", startOffset: 30)
        let empty = makeTrip(title: "Empty", startOffset: 60)
        let docEarly = TravelDocument(
            tripId: early.id,
            fileName: "E",
            localRelativePath: "Attachments/e.pdf",
            fileType: "pdf",
            createdAt: Date(timeIntervalSince1970: 100)
        )
        let docLater = TravelDocument(
            tripId: later.id,
            fileName: "L",
            localRelativePath: "Attachments/l.pdf",
            fileType: "pdf",
            createdAt: Date(timeIntervalSince1970: 200)
        )

        let trips = MockTripRepository()
        await trips.seed([later, early, empty])
        let docs = MockDocumentRepository()
        await docs.seed([docLater, docEarly])
        let vm = makeViewModel(docs: docs, trips: trips)
        await vm.load()

        let groups = vm.groupedDocuments
        XCTAssertEqual(groups.map(\.trip.title), ["Lisbon", "Tokyo"])
        XCTAssertEqual(groups.first?.documents.map(\.fileName), ["E"])
    }

    // MARK: - Helpers

    private struct ImportEnv {
        let vm: DocumentVaultViewModel
        let documents: MockDocumentRepository
        let storage: MockDocumentStorageService
    }

    private func makeImportEnv(
        seedingTrip trip: Trip,
        seedingItem item: ItineraryItem? = nil,
        seedingDocuments docs: [TravelDocument] = []
    ) async -> ImportEnv {
        let documents = MockDocumentRepository()
        await documents.seedTripIds([trip.id])
        if let item { await documents.seedItemIds([item.id]) }
        if !docs.isEmpty { await documents.seed(docs) }
        let storage = MockDocumentStorageService()
        let trips = MockTripRepository()
        await trips.seed([trip])
        let itinerary = MockItineraryRepository()
        if let item { await itinerary.seed([item]) }
        let vm = makeViewModel(docs: documents, trips: trips, itinerary: itinerary, storage: storage)
        return ImportEnv(vm: vm, documents: documents, storage: storage)
    }

    private func makeViewModel(
        docs: MockDocumentRepository = MockDocumentRepository(),
        trips: MockTripRepository = MockTripRepository(),
        itinerary: MockItineraryRepository = MockItineraryRepository(),
        storage: MockDocumentStorageService = MockDocumentStorageService()
    ) -> DocumentVaultViewModel {
        DocumentVaultViewModel(
            documentRepository: docs,
            tripRepository: trips,
            itineraryRepository: itinerary,
            storage: storage,
            now: { Date(timeIntervalSince1970: 1_800_000_000) }
        )
    }

    private func makeTrip(title: String, startOffset: Int = 1) -> Trip {
        let start = Calendar.current.date(byAdding: .day, value: startOffset, to: Date()) ?? Date()
        let end = Calendar.current.date(byAdding: .day, value: startOffset + 3, to: Date()) ?? start
        return Trip(title: title, destination: "\(title) City", startDate: start, endDate: end)
    }

    private func jpegPayload() -> Data {
        let header = Data([0xFF, 0xD8, 0xFF])
        return header + Data(repeating: 0xAB, count: 256)
    }
}
