import Foundation
import Combine

@MainActor
final class DocumentVaultViewModel: ObservableObject {
    @Published private(set) var documents: [TravelDocument] = []
    @Published private(set) var trips: [Trip] = []
    @Published private(set) var itemsByTripId: [UUID: [ItineraryItem]] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var isAttaching = false
    @Published var errorMessage: String?

    // Drives the import sheet. Set by stageFile/stagePhoto, cleared by
    // confirmImport on success or cancelImport.
    @Published var pendingImport: StagedFile?

    // Bound to .fileImporter and .photosPicker on the view.
    @Published var isPickingFile = false
    @Published var isPickingPhoto = false

    private let documentRepository: DocumentRepository
    private let tripRepository: TripRepository
    private let itineraryRepository: ItineraryRepository
    private let storage: DocumentStorageService
    private let now: @Sendable () -> Date
    private let temporaryDirectory: @Sendable () -> URL
    private let fileManager: FileManager

    init(
        documentRepository: DocumentRepository,
        tripRepository: TripRepository,
        itineraryRepository: ItineraryRepository,
        storage: DocumentStorageService,
        now: @escaping @Sendable () -> Date = { Date() },
        temporaryDirectory: @escaping @Sendable () -> URL = { FileManager.default.temporaryDirectory },
        fileManager: FileManager = .default
    ) {
        self.documentRepository = documentRepository
        self.tripRepository = tripRepository
        self.itineraryRepository = itineraryRepository
        self.storage = storage
        self.now = now
        self.temporaryDirectory = temporaryDirectory
        self.fileManager = fileManager
    }

    // MARK: - Load

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let docsTask = documentRepository.fetchAllDocuments()
            async let tripsTask = tripRepository.fetchTrips()
            let loadedDocs = try await docsTask
            let loadedTrips = try await tripsTask

            // Fetch items per trip so the import sheet has them ready. Per-trip
            // failures are tolerated — an unreadable trip's items map stays
            // empty, the import sheet just won't offer per-item association.
            var newItemsByTripId: [UUID: [ItineraryItem]] = [:]
            for trip in loadedTrips {
                if let items = try? await itineraryRepository.fetchItems(for: trip.id) {
                    newItemsByTripId[trip.id] = items
                }
            }

            self.documents = loadedDocs
            self.trips = loadedTrips
            self.itemsByTripId = newItemsByTripId
            self.errorMessage = nil
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Staging

    // Copies the picked file into a temp URL we own, freeing the
    // security-scoped source URL before the import sheet appears. Done
    // synchronously so the security scope is still held by the caller.
    func stageFile(at sourceURL: URL) {
        let needsAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if needsAccess { sourceURL.stopAccessingSecurityScopedResource() }
        }

        let ext = sourceURL.pathExtension.lowercased()
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let tempURL = makeStagingURL(extension: ext)

        do {
            try fileManager.copyItem(at: sourceURL, to: tempURL)
            pendingImport = StagedFile(
                url: tempURL,
                suggestedFileName: baseName,
                fileType: ext
            )
        } catch {
            errorMessage = "Couldn't read the selected file."
        }
    }

    // Writes raw photo bytes (from PhotosPicker) to a temp file. Detects
    // PNG / JPEG / HEIC from the magic bytes so the on-disk extension matches
    // the actual format.
    func stagePhoto(data: Data, capturedAt: Date) {
        let format = ImageFormatDetection.detect(data) ?? .jpeg
        let timestamp = Self.timestampFormatter.string(from: capturedAt)
        let baseName = format == .png ? "Screenshot" : "Photo"
        let fileName = "\(baseName)-\(timestamp)"
        let tempURL = makeStagingURL(extension: format.fileExtension)

        do {
            try data.write(to: tempURL, options: .atomic)
            pendingImport = StagedFile(
                url: tempURL,
                suggestedFileName: fileName,
                fileType: format.fileExtension
            )
        } catch {
            errorMessage = "Couldn't save the photo."
        }
    }

    private func makeStagingURL(extension ext: String) -> URL {
        let name = "TripKite-Staging-\(UUID().uuidString)"
        let suffix = ext.isEmpty ? "" : ".\(ext)"
        return temporaryDirectory().appendingPathComponent("\(name)\(suffix)")
    }

    // MARK: - Confirm / cancel

    func confirmImport(tripId: UUID, itemId: UUID?) async {
        guard let staged = pendingImport else { return }
        isAttaching = true
        defer { isAttaching = false }

        // First write: temp → sandbox (storage service handles the size cap
        // and security scope; our temp URL is unscoped so it's a plain copy).
        let document: TravelDocument
        do {
            document = try await storage.saveDocument(
                from: staged.url,
                suggestedFileName: staged.suggestedFileName,
                tripId: tripId,
                itineraryItemId: itemId,
                now: now()
            )
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        // Storage write succeeded — the temp file has served its purpose. Drop
        // it regardless of whether the metadata write below succeeds.
        try? fileManager.removeItem(at: staged.url)
        pendingImport = nil

        // Second write: Core Data metadata. On failure, roll back the file we
        // just wrote to the sandbox so we don't leave an orphan attachment.
        do {
            try await documentRepository.createDocument(document)
            documents.append(document)
            documents.sort { $0.createdAt > $1.createdAt }
            errorMessage = nil
        } catch {
            try? await storage.deleteFile(at: document.localRelativePath)
            errorMessage = error.localizedDescription
        }
    }

    func cancelImport() {
        if let url = pendingImport?.url {
            try? fileManager.removeItem(at: url)
        }
        pendingImport = nil
    }

    // MARK: - Per-row operations

    // Display-name rename. The on-disk path and stored file type are
    // unchanged. If the user types a trailing extension that matches the
    // stored fileType, it's stripped (case-insensitive) — same rule as the
    // per-trip section.
    func renameDocument(_ document: TravelDocument, to newName: String) async {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Please enter a name."
            return
        }
        let resolvedName = DocumentListViewModel.strippingExtensionIfMatches(trimmed, fileType: document.fileType)

        var updated = document
        updated.fileName = resolvedName

        do {
            try await documentRepository.updateDocument(updated)
            if let index = documents.firstIndex(where: { $0.id == updated.id }) {
                documents[index] = updated
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // Pass nil to move the document back to trip-level. The trip is never
    // changed here — documents do not move between trips in V2.3.
    func setAssociation(for document: TravelDocument, itineraryItemId: UUID?) async {
        var updated = document
        updated.itineraryItemId = itineraryItemId

        do {
            try await documentRepository.updateDocument(updated)
            if let index = documents.firstIndex(where: { $0.id == updated.id }) {
                documents[index] = updated
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ document: TravelDocument) async {
        do {
            try await documentRepository.deleteDocument(id: document.id)
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        try? await storage.deleteFile(at: document.localRelativePath)
        documents.removeAll { $0.id == document.id }
        errorMessage = nil
    }

    func absoluteURL(for document: TravelDocument) -> URL? {
        try? storage.absoluteURL(for: document)
    }

    // MARK: - Derived

    // Documents grouped by their trip. Trips are ordered by start date
    // ascending so the user's earliest planned trip surfaces first. Trips
    // with no documents are omitted. Within each group, the newest document
    // is on top.
    var groupedDocuments: [(trip: Trip, documents: [TravelDocument])] {
        trips
            .sorted { $0.startDate < $1.startDate }
            .compactMap { trip in
                let tripDocs = documents
                    .filter { $0.tripId == trip.id }
                    .sorted { $0.createdAt > $1.createdAt }
                guard !tripDocs.isEmpty else { return nil }
                return (trip: trip, documents: tripDocs)
            }
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        return formatter
    }()
}

struct StagedFile: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let suggestedFileName: String
    let fileType: String
}
