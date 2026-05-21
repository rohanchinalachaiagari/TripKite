import Foundation

protocol ItineraryRepository: Sendable {
    func fetchItems(for tripId: UUID) async throws -> [ItineraryItem]
    // Every itinerary item across every trip, sorted startDate ascending. Used
    // by the global Search tab so a single query can scan items without first
    // enumerating trips.
    func fetchAllItems() async throws -> [ItineraryItem]
    func item(with id: UUID) async throws -> ItineraryItem?
    func createItem(_ item: ItineraryItem) async throws
    func updateItem(_ item: ItineraryItem) async throws
    func deleteItem(id: UUID) async throws
}

enum ItineraryRepositoryError: LocalizedError, Equatable {
    case notFound
    case tripNotFound

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Itinerary item not found."
        case .tripNotFound:
            return "Couldn't find the trip for this itinerary item."
        }
    }
}
