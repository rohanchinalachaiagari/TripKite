import Foundation

protocol DataManagementService: Sendable {
    // Wipes every trip, itinerary item, document record, attachment file, and
    // pending reminder, then resets persisted settings. Idempotent — running
    // it twice on an empty store is a no-op.
    func clearAllData() async throws
}

nonisolated final class LocalDataManagementService: DataManagementService, @unchecked Sendable {
    private let tripRepository: TripRepository
    private let documentRepository: DocumentRepository
    private let documentStorage: DocumentStorageService
    private let notificationService: NotificationSchedulingService
    private let settingsStore: SettingsStore

    init(
        tripRepository: TripRepository,
        documentRepository: DocumentRepository,
        documentStorage: DocumentStorageService,
        notificationService: NotificationSchedulingService,
        settingsStore: SettingsStore
    ) {
        self.tripRepository = tripRepository
        self.documentRepository = documentRepository
        self.documentStorage = documentStorage
        self.notificationService = notificationService
        self.settingsStore = settingsStore
    }

    func clearAllData() async throws {
        let trips = try await tripRepository.fetchTrips()

        // For each trip: cancel its scheduled reminders, snapshot its document
        // file paths, delete the trip (Core Data cascades items + document
        // records), then sweep the files. Per-file file-delete failures are
        // tolerated so a single missing file doesn't block the whole wipe;
        // the trip record itself failing to delete IS surfaced.
        for trip in trips {
            await notificationService.cancelReminders(forTripId: trip.id)

            let documentPaths = ((try? await documentRepository.fetchDocuments(for: trip.id)) ?? [])
                .map(\.localRelativePath)

            try await tripRepository.deleteTrip(id: trip.id)

            for path in documentPaths {
                try? await documentStorage.deleteFile(at: path)
            }
        }

        settingsStore.reset()
    }
}
