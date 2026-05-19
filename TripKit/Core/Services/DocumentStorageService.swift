import Foundation

protocol DocumentStorageService: Sendable {
    // Copies the file at sourceURL into the sandbox and returns the metadata
    // the caller should persist via DocumentRepository. Does not touch Core Data.
    // The `now` parameter is the createdAt timestamp to record on the metadata.
    func saveDocument(
        from sourceURL: URL,
        suggestedFileName: String,
        tripId: UUID,
        itineraryItemId: UUID?,
        now: Date
    ) async throws -> TravelDocument

    // Writes raw bytes (e.g., from PhotosPicker) into the sandbox. The caller
    // is responsible for choosing the display fileName and fileType — the
    // service does no format detection on the data, only honors the 25 MB cap.
    func saveDocument(
        from data: Data,
        fileName: String,
        fileType: String,
        tripId: UUID,
        itineraryItemId: UUID?,
        now: Date
    ) async throws -> TravelDocument

    // Removes the file at the given relative path. Idempotent — missing files
    // are not treated as an error so callers can safely roll back partial saves.
    func deleteFile(at relativePath: String) async throws

    // Resolves a stored document's relative path to an absolute URL for preview
    // or sharing.
    func absoluteURL(for document: TravelDocument) throws -> URL
}

enum DocumentStorageError: LocalizedError, Equatable {
    case sourceUnreadable
    case destinationUnwritable
    case sandboxUnavailable
    case fileTooLarge(maxBytes: Int64)

    var errorDescription: String? {
        switch self {
        case .sourceUnreadable:
            return "Couldn't read the selected file."
        case .destinationUnwritable:
            return "Couldn't save the file to TripKite."
        case .sandboxUnavailable:
            return "TripKite's storage location is unavailable."
        case .fileTooLarge(let maxBytes):
            let formatted = ByteCountFormatter.string(fromByteCount: maxBytes, countStyle: .file)
            return "This file is too large. Attachments must be \(formatted) or smaller."
        }
    }
}

nonisolated final class FileManagerDocumentStorageService: DocumentStorageService, @unchecked Sendable {
    static let attachmentsSubdirectory = "Attachments"

    // V1 size cap: a single attachment can be at most 25 MB. Travel documents
    // (PDFs of confirmations, screenshots, ticket photos) are typically well
    // under this. The cap avoids accidentally inflating the user's iCloud
    // backup with a multi-GB file from iCloud Drive, and keeps the synchronous
    // copy inside the picker dismissal from stalling on a huge import.
    static let defaultMaxFileSizeBytes: Int64 = 25 * 1024 * 1024

    private let fileManager: FileManager
    private let maxFileSizeBytes: Int64
    private let documentsDirectoryProvider: @Sendable () throws -> URL

    init(
        fileManager: FileManager = .default,
        maxFileSizeBytes: Int64 = defaultMaxFileSizeBytes,
        documentsDirectoryProvider: @escaping @Sendable () throws -> URL = {
            guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                throw DocumentStorageError.sandboxUnavailable
            }
            return url
        }
    ) {
        self.fileManager = fileManager
        self.maxFileSizeBytes = maxFileSizeBytes
        self.documentsDirectoryProvider = documentsDirectoryProvider
    }

    func saveDocument(
        from sourceURL: URL,
        suggestedFileName: String,
        tripId: UUID,
        itineraryItemId: UUID?,
        now: Date
    ) async throws -> TravelDocument {
        // UIDocumentPicker hands back security-scoped URLs; not all sources do,
        // but the bracket pattern is safe either way.
        let needsAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if needsAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        guard fileManager.isReadableFile(atPath: sourceURL.path) else {
            throw DocumentStorageError.sourceUnreadable
        }

        // Pre-copy size guard. If the size is reported, refuse oversized files
        // before any bytes are copied. If the provider doesn't expose a size
        // (some File Provider extensions don't), fall through and let the copy
        // itself decide — FileManager will surface a real error on failure.
        if let values = try? sourceURL.resourceValues(forKeys: [.fileSizeKey]),
           let size = values.fileSize,
           Int64(size) > maxFileSizeBytes {
            throw DocumentStorageError.fileTooLarge(maxBytes: maxFileSizeBytes)
        }

        let documentsDir = try documentsDirectoryProvider()
        let attachmentsDir = documentsDir.appendingPathComponent(
            Self.attachmentsSubdirectory,
            isDirectory: true
        )

        do {
            try fileManager.createDirectory(at: attachmentsDir, withIntermediateDirectories: true)
        } catch {
            throw DocumentStorageError.destinationUnwritable
        }

        let documentId = UUID()
        let ext = sourceURL.pathExtension.lowercased()
        let destinationFileName = ext.isEmpty
            ? documentId.uuidString
            : "\(documentId.uuidString).\(ext)"
        let destinationURL = attachmentsDir.appendingPathComponent(destinationFileName)

        do {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
        } catch {
            throw DocumentStorageError.destinationUnwritable
        }

        let fileSize: Int64?
        if let values = try? destinationURL.resourceValues(forKeys: [.fileSizeKey]),
           let size = values.fileSize {
            fileSize = Int64(size)
        } else {
            fileSize = nil
        }

        let relativePath = "\(Self.attachmentsSubdirectory)/\(destinationFileName)"
        let displayName = suggestedFileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? sourceURL.lastPathComponent
            : suggestedFileName

        return TravelDocument(
            id: documentId,
            tripId: tripId,
            itineraryItemId: itineraryItemId,
            fileName: displayName,
            localRelativePath: relativePath,
            fileType: ext,
            fileSize: fileSize,
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
        let bytes = Int64(data.count)
        guard bytes <= maxFileSizeBytes else {
            throw DocumentStorageError.fileTooLarge(maxBytes: maxFileSizeBytes)
        }

        let documentsDir = try documentsDirectoryProvider()
        let attachmentsDir = documentsDir.appendingPathComponent(
            Self.attachmentsSubdirectory,
            isDirectory: true
        )

        do {
            try fileManager.createDirectory(at: attachmentsDir, withIntermediateDirectories: true)
        } catch {
            throw DocumentStorageError.destinationUnwritable
        }

        let documentId = UUID()
        let ext = fileType.lowercased()
        let destinationFileName = ext.isEmpty
            ? documentId.uuidString
            : "\(documentId.uuidString).\(ext)"
        let destinationURL = attachmentsDir.appendingPathComponent(destinationFileName)

        do {
            try data.write(to: destinationURL, options: .atomic)
        } catch {
            throw DocumentStorageError.destinationUnwritable
        }

        let relativePath = "\(Self.attachmentsSubdirectory)/\(destinationFileName)"
        let displayName = fileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? destinationFileName
            : fileName

        return TravelDocument(
            id: documentId,
            tripId: tripId,
            itineraryItemId: itineraryItemId,
            fileName: displayName,
            localRelativePath: relativePath,
            fileType: ext,
            fileSize: bytes,
            createdAt: now
        )
    }

    func deleteFile(at relativePath: String) async throws {
        let documentsDir = try documentsDirectoryProvider()
        let url = documentsDir.appendingPathComponent(relativePath)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    func absoluteURL(for document: TravelDocument) throws -> URL {
        let documentsDir = try documentsDirectoryProvider()
        return documentsDir.appendingPathComponent(document.localRelativePath)
    }
}
