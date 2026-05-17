import Foundation

protocol TripRepository: Sendable {
    func fetchTrips() async throws -> [Trip]
    func trip(with id: UUID) async throws -> Trip?
    func createTrip(_ trip: Trip) async throws
    func updateTrip(_ trip: Trip) async throws
    func deleteTrip(id: UUID) async throws
}

enum TripRepositoryError: LocalizedError, Equatable {
    case notFound

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Trip not found."
        }
    }
}
