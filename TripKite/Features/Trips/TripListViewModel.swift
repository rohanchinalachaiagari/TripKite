import Foundation
import Combine

@MainActor
final class TripListViewModel: ObservableObject {
    @Published private(set) var trips: [Trip] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let repository: TripRepository
    private let notificationService: NotificationSchedulingService
    private let documentRepository: DocumentRepository
    private let documentStorage: DocumentStorageService
    private let dateProvider: @Sendable () -> Date

    init(
        repository: TripRepository,
        notificationService: NotificationSchedulingService,
        documentRepository: DocumentRepository,
        documentStorage: DocumentStorageService,
        dateProvider: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.repository = repository
        self.notificationService = notificationService
        self.documentRepository = documentRepository
        self.documentStorage = documentStorage
        self.dateProvider = dateProvider
    }

    // Trips currently in progress. Sort soonest ending first so a trip that's
    // wrapping up today sits above one that ends next week.
    var activeTrips: [Trip] {
        let now = dateProvider()
        return trips
            .filter { $0.status(relativeTo: now) == .active }
            .sorted { $0.endDate < $1.endDate }
    }

    // Trips that haven't started yet. Active trips are deliberately excluded
    // here so they appear only in `activeTrips`; an active trip is not
    // "upcoming" anymore.
    var upcomingTrips: [Trip] {
        let now = dateProvider()
        return trips
            .filter { $0.status(relativeTo: now) == .upcoming }
            .sorted { $0.startDate < $1.startDate }
    }

    // Trips that have already ended. Sort most recently ended first so a
    // trip from last week sits above one from a year ago.
    var pastTrips: [Trip] {
        let now = dateProvider()
        return trips
            .filter { $0.status(relativeTo: now) == .past }
            .sorted { $0.endDate > $1.endDate }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            trips = try await repository.fetchTrips()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ trip: Trip) async {
        await notificationService.cancelReminders(forTripId: trip.id)

        // Capture document file paths before the trip cascade-deletes the
        // metadata records. Fetch failures aren't fatal — we'll just leave
        // those files orphaned rather than blocking the trip delete.
        let filePaths: [String]
        if let documents = try? await documentRepository.fetchDocuments(for: trip.id) {
            filePaths = documents.map(\.localRelativePath)
        } else {
            filePaths = []
        }

        do {
            try await repository.deleteTrip(id: trip.id)
            trips.removeAll { $0.id == trip.id }
            errorMessage = nil

            // Trip + cascaded document records are gone; clear the files. Any
            // individual failure here is logged-by-omission rather than user-visible.
            for path in filePaths {
                try? await documentStorage.deleteFile(at: path)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
