import Foundation
@testable import TripKite

final actor MockTripRepository: TripRepository {
    private(set) var storage: [UUID: Trip] = [:]
    private(set) var createCallCount = 0
    private(set) var updateCallCount = 0
    private(set) var deleteCallCount = 0
    private(set) var fetchCallCount = 0

    private var fetchError: Error?
    private var createError: Error?
    private var updateError: Error?
    private var deleteError: Error?

    func seed(_ trips: [Trip]) {
        for trip in trips {
            storage[trip.id] = trip
        }
    }

    func setFetchError(_ error: Error?) { fetchError = error }
    func setCreateError(_ error: Error?) { createError = error }
    func setUpdateError(_ error: Error?) { updateError = error }
    func setDeleteError(_ error: Error?) { deleteError = error }

    func fetchTrips() async throws -> [Trip] {
        fetchCallCount += 1
        if let fetchError { throw fetchError }
        return Array(storage.values).sorted { $0.startDate < $1.startDate }
    }

    func trip(with id: UUID) async throws -> Trip? {
        storage[id]
    }

    func createTrip(_ trip: Trip) async throws {
        createCallCount += 1
        if let createError { throw createError }
        storage[trip.id] = trip
    }

    func updateTrip(_ trip: Trip) async throws {
        updateCallCount += 1
        if let updateError { throw updateError }
        guard storage[trip.id] != nil else {
            throw TripRepositoryError.notFound
        }
        storage[trip.id] = trip
    }

    func deleteTrip(id: UUID) async throws {
        deleteCallCount += 1
        if let deleteError { throw deleteError }
        storage.removeValue(forKey: id)
    }
}
