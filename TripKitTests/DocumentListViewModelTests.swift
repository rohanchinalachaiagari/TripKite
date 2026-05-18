import XCTest
@testable import TripKit

@MainActor
final class DocumentListViewModelTests: XCTestCase {

    func testLoad_PopulatesDocuments() async {
        let tripId = UUID()
        let repo = MockDocumentRepository()
        let existing = TravelDocument(
            tripId: tripId,
            fileName: "Existing.pdf",
            localRelativePath: "Attachments/existing.pdf",
            fileType: "pdf"
        )
        await repo.seed([existing])
        let storage = MockDocumentStorageService()

        let vm = DocumentListViewModel(tripId: tripId, repository: repo, storage: storage)
        await vm.load()

        XCTAssertEqual(vm.documents.map(\.fileName), ["Existing.pdf"])
        XCTAssertNil(vm.errorMessage)
    }

    func testLoad_OnError_SetsErrorMessage() async {
        let repo = MockDocumentRepository()
        struct BoomError: LocalizedError { var errorDescription: String? { "Boom" } }
        await repo.setFetchError(BoomError())
        let storage = MockDocumentStorageService()

        let vm = DocumentListViewModel(tripId: UUID(), repository: repo, storage: storage)
        await vm.load()

        XCTAssertTrue(vm.documents.isEmpty)
        XCTAssertEqual(vm.errorMessage, "Boom")
    }

    func testAttach_CallsStorageThenRepository() async {
        let tripId = UUID()
        let repo = MockDocumentRepository()
        await repo.seedTripIds([tripId])
        let storage = MockDocumentStorageService()

        let vm = DocumentListViewModel(tripId: tripId, repository: repo, storage: storage)
        await vm.attach(from: URL(fileURLWithPath: "/tmp/example.pdf"))

        let saveCalls = await storage.saveCalls
        let createCount = await repo.createCallCount
        XCTAssertEqual(saveCalls.count, 1)
        XCTAssertEqual(saveCalls.first?.tripId, tripId)
        XCTAssertEqual(createCount, 1)
        XCTAssertEqual(vm.documents.count, 1)
        XCTAssertNil(vm.errorMessage)
    }

    func testAttach_WhenRepositoryFails_RollsBackFile() async {
        let tripId = UUID()
        let repo = MockDocumentRepository()
        await repo.seedTripIds([tripId])
        struct BoomError: LocalizedError { var errorDescription: String? { "DB failure" } }
        await repo.setCreateError(BoomError())
        let storage = MockDocumentStorageService()

        let vm = DocumentListViewModel(tripId: tripId, repository: repo, storage: storage)
        await vm.attach(from: URL(fileURLWithPath: "/tmp/example.pdf"))

        let deleteCalls = await storage.deleteCalls
        let remaining = await storage.savedPaths
        XCTAssertEqual(deleteCalls.count, 1, "File should be rolled back after repo failure")
        XCTAssertTrue(remaining.isEmpty)
        XCTAssertTrue(vm.documents.isEmpty)
        XCTAssertEqual(vm.errorMessage, "DB failure")
    }

    func testAttachPhoto_DetectsFormatAndPersists() async {
        let tripId = UUID()
        let repo = MockDocumentRepository()
        await repo.seedTripIds([tripId])
        let storage = MockDocumentStorageService()

        // PNG magic-byte header so the detector picks `.png` → "Screenshot-..."
        let pngHeader = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        let payload = pngHeader + Data(repeating: 0xFF, count: 512)

        let vm = DocumentListViewModel(tripId: tripId, repository: repo, storage: storage)
        await vm.attachPhoto(data: payload, capturedAt: Date(timeIntervalSince1970: 1_700_000_000))

        let saveCalls = await storage.saveCalls
        let createCount = await repo.createCallCount
        XCTAssertEqual(saveCalls.count, 1)
        XCTAssertEqual(createCount, 1)
        XCTAssertEqual(vm.documents.count, 1)
        let saved = vm.documents.first
        XCTAssertEqual(saved?.fileType, "png")
        XCTAssertTrue(saved?.fileName.hasPrefix("Screenshot-") ?? false,
                      "Expected PNG payload to be named with 'Screenshot-' prefix, got \(saved?.fileName ?? "nil")")
        XCTAssertNil(vm.errorMessage)
    }

    func testAttachPhoto_UnknownFormatFallsBackToJPEG() async {
        let tripId = UUID()
        let repo = MockDocumentRepository()
        await repo.seedTripIds([tripId])
        let storage = MockDocumentStorageService()

        let payload = Data(repeating: 0x00, count: 64)

        let vm = DocumentListViewModel(tripId: tripId, repository: repo, storage: storage)
        await vm.attachPhoto(data: payload, capturedAt: Date(timeIntervalSince1970: 1_700_000_000))

        let saved = vm.documents.first
        XCTAssertEqual(saved?.fileType, "jpg")
        XCTAssertTrue(saved?.fileName.hasPrefix("Photo-") ?? false)
    }

    // MARK: - Rename

    func testRename_WithoutExtension_DisplaysExactName() async {
        let tripId = UUID()
        let original = TravelDocument(
            tripId: tripId,
            fileName: "Screenshot-2026-05-17",
            localRelativePath: "Attachments/abc.png",
            fileType: "png",
            fileSize: 1024
        )
        let repo = MockDocumentRepository()
        await repo.seed([original])
        let storage = MockDocumentStorageService()

        let vm = DocumentListViewModel(tripId: tripId, repository: repo, storage: storage)
        await vm.load()
        await vm.renameDocument(original, to: "Fogo receipt")

        let stored = await repo.storage[original.id]
        XCTAssertEqual(stored?.fileName, "Fogo receipt")
        XCTAssertEqual(vm.documents.first?.fileName, "Fogo receipt")
        XCTAssertEqual(stored?.fileType, "png")
        XCTAssertEqual(stored?.localRelativePath, "Attachments/abc.png")
        let updateCount = await repo.updateCallCount
        XCTAssertEqual(updateCount, 1)
        XCTAssertNil(vm.errorMessage)
    }

    func testRename_WithMatchingExtension_StripsItForDisplay() async {
        let tripId = UUID()
        let original = TravelDocument(
            tripId: tripId,
            fileName: "Screenshot-2026-05-17",
            localRelativePath: "Attachments/abc.png",
            fileType: "png"
        )
        let repo = MockDocumentRepository()
        await repo.seed([original])
        let storage = MockDocumentStorageService()

        let vm = DocumentListViewModel(tripId: tripId, repository: repo, storage: storage)
        await vm.load()
        await vm.renameDocument(original, to: "Fogo receipt.png")

        let stored = await repo.storage[original.id]
        XCTAssertEqual(stored?.fileName, "Fogo receipt")
        XCTAssertEqual(vm.documents.first?.fileName, "Fogo receipt")
    }

    func testRename_WithMatchingExtensionUppercase_StripsItForDisplay() async {
        let tripId = UUID()
        let original = TravelDocument(
            tripId: tripId,
            fileName: "Photo",
            localRelativePath: "Attachments/abc.png",
            fileType: "png"
        )
        let repo = MockDocumentRepository()
        await repo.seed([original])
        let storage = MockDocumentStorageService()

        let vm = DocumentListViewModel(tripId: tripId, repository: repo, storage: storage)
        await vm.load()
        await vm.renameDocument(original, to: "Fogo receipt.PNG")

        XCTAssertEqual(vm.documents.first?.fileName, "Fogo receipt")
    }

    func testRename_PreservesFileTypeAndPath() async {
        let tripId = UUID()
        let original = TravelDocument(
            tripId: tripId,
            fileName: "Original",
            localRelativePath: "Attachments/stable-uuid.png",
            fileType: "png"
        )
        let repo = MockDocumentRepository()
        await repo.seed([original])
        let storage = MockDocumentStorageService()

        let vm = DocumentListViewModel(tripId: tripId, repository: repo, storage: storage)
        await vm.load()
        await vm.renameDocument(original, to: "Fogo receipt.png")

        let stored = await repo.storage[original.id]
        XCTAssertEqual(stored?.fileType, "png", "fileType metadata must survive rename")
        XCTAssertEqual(stored?.localRelativePath, "Attachments/stable-uuid.png",
                       "Physical path must not change during rename")
        let deleteCalls = await storage.deleteCalls
        let saveCalls = await storage.saveCalls
        XCTAssertTrue(deleteCalls.isEmpty, "Storage service should not be touched during rename")
        XCTAssertTrue(saveCalls.isEmpty)
    }

    func testRename_EmptyAfterTrim_IsRejectedAndDoesNotPersist() async {
        let tripId = UUID()
        let original = TravelDocument(
            tripId: tripId,
            fileName: "Photo",
            localRelativePath: "Attachments/abc.png",
            fileType: "png"
        )
        let repo = MockDocumentRepository()
        await repo.seed([original])
        let storage = MockDocumentStorageService()

        let vm = DocumentListViewModel(tripId: tripId, repository: repo, storage: storage)
        await vm.load()
        await vm.renameDocument(original, to: "   ")

        let stored = await repo.storage[original.id]
        XCTAssertEqual(stored?.fileName, "Photo")
        XCTAssertEqual(vm.documents.first?.fileName, "Photo")
        let updateCount = await repo.updateCallCount
        XCTAssertEqual(updateCount, 0)
        XCTAssertNotNil(vm.errorMessage)
    }

    func testDelete_RemovesRecordThenFile() async {
        let tripId = UUID()
        let doc = TravelDocument(
            tripId: tripId,
            fileName: "Doomed.pdf",
            localRelativePath: "Attachments/doomed.pdf",
            fileType: "pdf"
        )
        let repo = MockDocumentRepository()
        await repo.seed([doc])
        let storage = MockDocumentStorageService()

        let vm = DocumentListViewModel(tripId: tripId, repository: repo, storage: storage)
        await vm.load()
        await vm.delete(doc)

        let deleteCount = await repo.deleteCallCount
        let storageDeleteCalls = await storage.deleteCalls
        XCTAssertEqual(deleteCount, 1)
        XCTAssertEqual(storageDeleteCalls, [doc.localRelativePath])
        XCTAssertTrue(vm.documents.isEmpty)
    }

    func testDelete_WhenRepoFails_DoesNotDeleteFile() async {
        let tripId = UUID()
        let doc = TravelDocument(
            tripId: tripId,
            fileName: "Stuck.pdf",
            localRelativePath: "Attachments/stuck.pdf",
            fileType: "pdf"
        )
        let repo = MockDocumentRepository()
        await repo.seed([doc])
        struct BoomError: LocalizedError { var errorDescription: String? { "Nope" } }
        await repo.setDeleteError(BoomError())
        let storage = MockDocumentStorageService()

        let vm = DocumentListViewModel(tripId: tripId, repository: repo, storage: storage)
        await vm.load()
        await vm.delete(doc)

        let storageDeleteCalls = await storage.deleteCalls
        XCTAssertTrue(storageDeleteCalls.isEmpty, "File should remain when the record delete fails")
        XCTAssertEqual(vm.documents.count, 1, "Document should still be in the list")
        XCTAssertEqual(vm.errorMessage, "Nope")
    }
}
