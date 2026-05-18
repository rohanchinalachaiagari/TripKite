import Foundation
import Combine

@MainActor
final class DocumentListViewModel: ObservableObject {
    @Published private(set) var documents: [TravelDocument] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isAttaching = false
    @Published var errorMessage: String?

    private let tripId: UUID
    private let repository: DocumentRepository
    private let storage: DocumentStorageService
    private let now: @Sendable () -> Date

    init(
        tripId: UUID,
        repository: DocumentRepository,
        storage: DocumentStorageService,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.tripId = tripId
        self.repository = repository
        self.storage = storage
        self.now = now
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            documents = try await repository.fetchDocuments(for: tripId)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func attach(from sourceURL: URL) async {
        isAttaching = true
        defer { isAttaching = false }

        // Strip the extension from the display name; the type is shown separately
        // in the row subtitle so we don't duplicate it in the title.
        let lastPathComponent = sourceURL.lastPathComponent
        let ext = sourceURL.pathExtension.lowercased()
        let displayName = Self.strippingExtensionIfMatches(lastPathComponent, fileType: ext)

        let document: TravelDocument
        do {
            document = try await storage.saveDocument(
                from: sourceURL,
                suggestedFileName: displayName,
                tripId: tripId,
                itineraryItemId: nil,
                now: now()
            )
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        do {
            try await repository.createDocument(document)
            documents.append(document)
            documents.sort { $0.createdAt < $1.createdAt }
            errorMessage = nil
        } catch {
            // Roll back the copied file so we don't leave orphans on disk.
            try? await storage.deleteFile(at: document.localRelativePath)
            errorMessage = error.localizedDescription
        }
    }

    func attachPhoto(data: Data, capturedAt: Date) async {
        isAttaching = true
        defer { isAttaching = false }

        let format = ImageFormatDetection.detect(data) ?? .jpeg
        let timestamp = Self.timestampFormatter.string(from: capturedAt)
        let baseName = format == .png ? "Screenshot" : "Photo"
        // Display name carries no extension; fileType is stored separately and
        // surfaces in the row subtitle.
        let fileName = "\(baseName)-\(timestamp)"

        let document: TravelDocument
        do {
            document = try await storage.saveDocument(
                from: data,
                fileName: fileName,
                fileType: format.fileExtension,
                tripId: tripId,
                itineraryItemId: nil,
                now: now()
            )
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        do {
            try await repository.createDocument(document)
            documents.append(document)
            documents.sort { $0.createdAt < $1.createdAt }
            errorMessage = nil
        } catch {
            try? await storage.deleteFile(at: document.localRelativePath)
            errorMessage = error.localizedDescription
        }
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        return formatter
    }()

    // Updates the user-facing fileName only. The physical file on disk and the
    // stored fileType / localRelativePath are unchanged. fileName is a display
    // label, not a filesystem name, so if the user types an extension that
    // matches the stored fileType we strip it; the type is shown separately in
    // the row subtitle.
    func renameDocument(_ document: TravelDocument, to newName: String) async {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Please enter a name."
            return
        }

        let resolvedName = Self.strippingExtensionIfMatches(trimmed, fileType: document.fileType)

        var updated = document
        updated.fileName = resolvedName

        do {
            try await repository.updateDocument(updated)
            if let index = documents.firstIndex(where: { $0.id == updated.id }) {
                documents[index] = updated
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // Updates only the item association. Trip is never changed; display name
    // and file type are untouched. Pass `nil` to move the document back to
    // trip-level.
    func setAssociation(for document: TravelDocument, itineraryItemId: UUID?) async {
        var updated = document
        updated.itineraryItemId = itineraryItemId

        do {
            try await repository.updateDocument(updated)
            if let index = documents.firstIndex(where: { $0.id == updated.id }) {
                documents[index] = updated
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // Set of itinerary item IDs that have at least one document attached. Used
    // by the timeline to render the paperclip indicator on each item row.
    var itemIdsWithAttachments: Set<UUID> {
        Set(documents.compactMap(\.itineraryItemId))
    }

    // Drops a trailing ".{fileType}" from `name` (case-insensitive match on the
    // extension portion only — the user's casing of the visible name is kept).
    // Returns `name` unchanged when there's no fileType, when the name doesn't
    // end with the matching suffix, or when stripping would leave an empty
    // string (e.g., the user entered exactly ".png").
    static func strippingExtensionIfMatches(_ name: String, fileType: String) -> String {
        guard !fileType.isEmpty else { return name }
        let suffix = ".\(fileType.lowercased())"
        guard name.lowercased().hasSuffix(suffix), name.count > suffix.count else {
            return name
        }
        return String(name.dropLast(suffix.count))
    }

    func delete(_ document: TravelDocument) async {
        do {
            try await repository.deleteDocument(id: document.id)
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        // Record is gone; the UI no longer references the file. If the file
        // delete fails we accept an orphan rather than failing the user-visible
        // delete operation.
        try? await storage.deleteFile(at: document.localRelativePath)
        documents.removeAll { $0.id == document.id }
        errorMessage = nil
    }

    func absoluteURL(for document: TravelDocument) -> URL? {
        try? storage.absoluteURL(for: document)
    }
}
