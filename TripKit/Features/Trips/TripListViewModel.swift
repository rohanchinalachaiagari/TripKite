import Foundation
import Combine

@MainActor
final class TripListViewModel: ObservableObject {
    @Published private(set) var trips: [Trip] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let repository: TripRepository
    private let notificationService: NotificationSchedulingService
    private let dateProvider: @Sendable () -> Date

    init(
        repository: TripRepository,
        notificationService: NotificationSchedulingService,
        dateProvider: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.repository = repository
        self.notificationService = notificationService
        self.dateProvider = dateProvider
    }

    var upcomingTrips: [Trip] {
        let now = dateProvider()
        return trips
            .filter { $0.status(relativeTo: now) != .past }
            .sorted { $0.startDate < $1.startDate }
    }

    var pastTrips: [Trip] {
        let now = dateProvider()
        return trips
            .filter { $0.status(relativeTo: now) == .past }
            .sorted { $0.startDate > $1.startDate }
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
        do {
            try await repository.deleteTrip(id: trip.id)
            trips.removeAll { $0.id == trip.id }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
