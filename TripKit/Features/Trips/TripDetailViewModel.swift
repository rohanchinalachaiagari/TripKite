import Foundation
import Combine

@MainActor
final class TripDetailViewModel: ObservableObject {
    @Published private(set) var trip: Trip
    @Published private(set) var items: [ItineraryItem] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let itineraryRepository: ItineraryRepository
    private let tripRepository: TripRepository

    init(
        trip: Trip,
        itineraryRepository: ItineraryRepository,
        tripRepository: TripRepository
    ) {
        self.trip = trip
        self.itineraryRepository = itineraryRepository
        self.tripRepository = tripRepository
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            items = try await itineraryRepository.fetchItems(for: trip.id)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteItem(_ item: ItineraryItem) async {
        do {
            try await itineraryRepository.deleteItem(id: item.id)
            items.removeAll { $0.id == item.id }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshTrip() async {
        if let updated = try? await tripRepository.trip(with: trip.id) {
            trip = updated
        }
    }
}
