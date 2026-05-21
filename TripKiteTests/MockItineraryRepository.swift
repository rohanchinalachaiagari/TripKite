import Foundation
@testable import TripKite

final actor MockItineraryRepository: ItineraryRepository {
    private(set) var storage: [UUID: ItineraryItem] = [:]
    private(set) var existingTripIds: Set<UUID> = []

    private(set) var fetchCallCount = 0
    private(set) var createCallCount = 0
    private(set) var updateCallCount = 0
    private(set) var deleteCallCount = 0

    private var fetchError: Error?
    private var createError: Error?
    private var updateError: Error?
    private var deleteError: Error?

    func seed(_ items: [ItineraryItem]) {
        for item in items {
            storage[item.id] = item
            existingTripIds.insert(item.tripId)
        }
    }

    func seedTripIds(_ ids: [UUID]) {
        for id in ids { existingTripIds.insert(id) }
    }

    func setFetchError(_ error: Error?) { fetchError = error }
    func setCreateError(_ error: Error?) { createError = error }
    func setUpdateError(_ error: Error?) { updateError = error }
    func setDeleteError(_ error: Error?) { deleteError = error }

    func fetchItems(for tripId: UUID) async throws -> [ItineraryItem] {
        fetchCallCount += 1
        if let fetchError { throw fetchError }
        return storage.values
            .filter { $0.tripId == tripId }
            .sorted { $0.startDate < $1.startDate }
    }

    func fetchAllItems() async throws -> [ItineraryItem] {
        fetchCallCount += 1
        if let fetchError { throw fetchError }
        return storage.values.sorted { $0.startDate < $1.startDate }
    }

    func item(with id: UUID) async throws -> ItineraryItem? {
        storage[id]
    }

    func createItem(_ item: ItineraryItem) async throws {
        createCallCount += 1
        if let createError { throw createError }
        guard existingTripIds.contains(item.tripId) else {
            throw ItineraryRepositoryError.tripNotFound
        }
        storage[item.id] = item
    }

    func updateItem(_ item: ItineraryItem) async throws {
        updateCallCount += 1
        if let updateError { throw updateError }
        guard storage[item.id] != nil else {
            throw ItineraryRepositoryError.notFound
        }
        storage[item.id] = item
    }

    func deleteItem(id: UUID) async throws {
        deleteCallCount += 1
        if let deleteError { throw deleteError }
        storage.removeValue(forKey: id)
    }
}
