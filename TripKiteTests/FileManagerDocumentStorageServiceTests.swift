import XCTest
@testable import TripKite

final class FileManagerDocumentStorageServiceTests: XCTestCase {
    private var tempDir: URL!
    private var service: FileManagerDocumentStorageService!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("TripKitTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let dirURL = tempDir!
        service = FileManagerDocumentStorageService(
            documentsDirectoryProvider: { dirURL }
        )
    }

    override func tearDownWithError() throws {
        if let tempDir, FileManager.default.fileExists(atPath: tempDir.path) {
            try FileManager.default.removeItem(at: tempDir)
        }
        tempDir = nil
        service = nil
        try super.tearDownWithError()
    }

    func testSaveDocument_CopiesFileIntoSandboxAndReturnsMetadata() async throws {
        let source = try writeTempSource(named: "ticket.pdf", contents: "hello")

        let doc = try await service.saveDocument(
            from: source,
            suggestedFileName: "Ticket.pdf",
            tripId: UUID(),
            itineraryItemId: nil,
            now: Date(timeIntervalSince1970: 1_700_000_000)
        )

        XCTAssertEqual(doc.fileType, "pdf")
        XCTAssertEqual(doc.fileName, "Ticket.pdf")
        XCTAssertTrue(doc.localRelativePath.hasPrefix("Attachments/"))
        XCTAssertTrue(doc.localRelativePath.hasSuffix(".pdf"))

        let absolute = try service.absoluteURL(for: doc)
        XCTAssertTrue(FileManager.default.fileExists(atPath: absolute.path))
    }

    func testSaveDocument_RecordsFileSize() async throws {
        let source = try writeTempSource(named: "report.pdf", contents: "0123456789")

        let doc = try await service.saveDocument(
            from: source,
            suggestedFileName: "report.pdf",
            tripId: UUID(),
            itineraryItemId: nil,
            now: Date()
        )

        XCTAssertEqual(doc.fileSize, 10)
    }

    func testSaveDocument_FallsBackToSourceFileNameWhenSuggestedIsBlank() async throws {
        let source = try writeTempSource(named: "boarding.pdf", contents: "x")

        let doc = try await service.saveDocument(
            from: source,
            suggestedFileName: "   ",
            tripId: UUID(),
            itineraryItemId: nil,
            now: Date()
        )

        XCTAssertEqual(doc.fileName, "boarding.pdf")
    }

    func testDeleteFile_RemovesFromDisk() async throws {
        let source = try writeTempSource(named: "delete.pdf", contents: "bye")
        let doc = try await service.saveDocument(
            from: source,
            suggestedFileName: "delete.pdf",
            tripId: UUID(),
            itineraryItemId: nil,
            now: Date()
        )

        try await service.deleteFile(at: doc.localRelativePath)

        let absolute = try service.absoluteURL(for: doc)
        XCTAssertFalse(FileManager.default.fileExists(atPath: absolute.path))
    }

    func testDeleteFile_WhenMissing_IsIdempotent() async throws {
        try await service.deleteFile(at: "Attachments/nope.pdf")
    }

    func testSaveDocument_FromData_WritesFileAndReturnsMetadata() async throws {
        let data = Data(repeating: 0x42, count: 256)

        let doc = try await service.saveDocument(
            from: data,
            fileName: "Photo-2026-05-17-21-42-12.jpg",
            fileType: "jpg",
            tripId: UUID(),
            itineraryItemId: nil,
            now: Date(timeIntervalSince1970: 1_700_000_000)
        )

        XCTAssertEqual(doc.fileName, "Photo-2026-05-17-21-42-12.jpg")
        XCTAssertEqual(doc.fileType, "jpg")
        XCTAssertEqual(doc.fileSize, 256)
        XCTAssertTrue(doc.localRelativePath.hasSuffix(".jpg"))

        let absolute = try service.absoluteURL(for: doc)
        XCTAssertTrue(FileManager.default.fileExists(atPath: absolute.path))
        let onDisk = try Data(contentsOf: absolute)
        XCTAssertEqual(onDisk.count, 256)
    }

    func testSaveDocument_FromData_OversizedThrowsFileTooLargeAndSkipsWrite() async throws {
        let dirURL = tempDir!
        let limitedService = FileManagerDocumentStorageService(
            maxFileSizeBytes: 16,
            documentsDirectoryProvider: { dirURL }
        )
        let data = Data(repeating: 0xAB, count: 32)

        do {
            _ = try await limitedService.saveDocument(
                from: data,
                fileName: "Big.png",
                fileType: "png",
                tripId: UUID(),
                itineraryItemId: nil,
                now: Date()
            )
            XCTFail("Expected .fileTooLarge")
        } catch let error as DocumentStorageError {
            XCTAssertEqual(error, .fileTooLarge(maxBytes: 16))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let attachmentsDir = tempDir.appendingPathComponent(
            FileManagerDocumentStorageService.attachmentsSubdirectory,
            isDirectory: true
        )
        let written = (try? FileManager.default.contentsOfDirectory(atPath: attachmentsDir.path)) ?? []
        XCTAssertTrue(written.isEmpty)
    }

    func testSaveDocument_WhenSourceExceedsMaxFileSize_ThrowsFileTooLargeAndSkipsCopy() async throws {
        // Use a tiny synthetic max so we don't need to write a real 25 MB
        // file in the test suite.
        let dirURL = tempDir!
        let limitedService = FileManagerDocumentStorageService(
            maxFileSizeBytes: 8,
            documentsDirectoryProvider: { dirURL }
        )
        let source = try writeTempSource(named: "huge.pdf", contents: "way too long for the limit")

        do {
            _ = try await limitedService.saveDocument(
                from: source,
                suggestedFileName: "huge.pdf",
                tripId: UUID(),
                itineraryItemId: nil,
                now: Date()
            )
            XCTFail("Expected saveDocument to throw .fileTooLarge")
        } catch let error as DocumentStorageError {
            XCTAssertEqual(error, .fileTooLarge(maxBytes: 8))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        // No file should have been copied into the attachments directory.
        let attachmentsDir = tempDir.appendingPathComponent(
            FileManagerDocumentStorageService.attachmentsSubdirectory,
            isDirectory: true
        )
        let copiedFiles = (try? FileManager.default.contentsOfDirectory(atPath: attachmentsDir.path)) ?? []
        XCTAssertTrue(copiedFiles.isEmpty, "Oversized file should not be copied into the sandbox")
    }

    func testAbsoluteURL_ResolvesUnderProvidedDirectory() throws {
        let doc = TravelDocument(
            tripId: UUID(),
            fileName: "x",
            localRelativePath: "Attachments/abc.pdf",
            fileType: "pdf"
        )
        let resolved = try service.absoluteURL(for: doc)
        XCTAssertEqual(resolved.path, tempDir.appendingPathComponent("Attachments/abc.pdf").path)
    }

    // MARK: - Helpers

    private func writeTempSource(named name: String, contents: String) throws -> URL {
        let url = tempDir
            .appendingPathComponent("source-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let file = url.appendingPathComponent(name)
        try contents.data(using: .utf8)!.write(to: file)
        return file
    }
}
