import Foundation
@testable import TripKite

final actor MockDocumentStorageService: DocumentStorageService {
    private(set) var savedPaths: Set<String> = []
    private(set) var saveCalls: [(sourceURL: URL, tripId: UUID, itemId: UUID?)] = []
    private(set) var deleteCalls: [String] = []

    private var saveError: Error?

    func setSaveError(_ error: Error?) { saveError = error }

    func saveDocument(
        from sourceURL: URL,
        suggestedFileName: String,
        tripId: UUID,
        itineraryItemId: UUID?,
        now: Date
    ) async throws -> TravelDocument {
        if let saveError { throw saveError }
        saveCalls.append((sourceURL, tripId, itineraryItemId))

        let documentId = UUID()
        let ext = sourceURL.pathExtension.lowercased()
        let relativePath = "Attachments/\(documentId.uuidString)\(ext.isEmpty ? "" : ".\(ext)")"
        savedPaths.insert(relativePath)

        return TravelDocument(
            id: documentId,
            tripId: tripId,
            itineraryItemId: itineraryItemId,
            fileName: suggestedFileName.isEmpty ? sourceURL.lastPathComponent : suggestedFileName,
            localRelativePath: relativePath,
            fileType: ext,
            fileSize: 1024,
            createdAt: now
        )
    }

    func saveDocument(
        from data: Data,
        fileName: String,
        fileType: String,
        tripId: UUID,
        itineraryItemId: UUID?,
        now: Date
    ) async throws -> TravelDocument {
        if let saveError { throw saveError }
        saveCalls.append((URL(fileURLWithPath: "/mock/\(fileName)"), tripId, itineraryItemId))

        let documentId = UUID()
        let ext = fileType.lowercased()
        let relativePath = "Attachments/\(documentId.uuidString)\(ext.isEmpty ? "" : ".\(ext)")"
        savedPaths.insert(relativePath)

        return TravelDocument(
            id: documentId,
            tripId: tripId,
            itineraryItemId: itineraryItemId,
            fileName: fileName,
            localRelativePath: relativePath,
            fileType: ext,
            fileSize: Int64(data.count),
            createdAt: now
        )
    }

    func deleteFile(at relativePath: String) async throws {
        deleteCalls.append(relativePath)
        savedPaths.remove(relativePath)
    }

    func absoluteURL(for document: TravelDocument) throws -> URL {
        URL(fileURLWithPath: "/mock/\(document.localRelativePath)")
    }
}
