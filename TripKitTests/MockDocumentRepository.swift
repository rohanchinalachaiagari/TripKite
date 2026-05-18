import Foundation
@testable import TripKit

final actor MockDocumentRepository: DocumentRepository {
    private(set) var storage: [UUID: TravelDocument] = [:]
    private(set) var existingTripIds: Set<UUID> = []
    private(set) var existingItemIds: Set<UUID> = []

    private(set) var fetchTripCount = 0
    private(set) var fetchItemCount = 0
    private(set) var createCallCount = 0
    private(set) var updateCallCount = 0
    private(set) var deleteCallCount = 0

    private var fetchError: Error?
    private var createError: Error?
    private var updateError: Error?
    private var deleteError: Error?

    func seed(_ documents: [TravelDocument]) {
        for doc in documents {
            storage[doc.id] = doc
            existingTripIds.insert(doc.tripId)
            if let itemId = doc.itineraryItemId { existingItemIds.insert(itemId) }
        }
    }

    func seedTripIds(_ ids: [UUID]) {
        for id in ids { existingTripIds.insert(id) }
    }

    func seedItemIds(_ ids: [UUID]) {
        for id in ids { existingItemIds.insert(id) }
    }

    func setFetchError(_ error: Error?) { fetchError = error }
    func setCreateError(_ error: Error?) { createError = error }
    func setUpdateError(_ error: Error?) { updateError = error }
    func setDeleteError(_ error: Error?) { deleteError = error }

    func fetchDocuments(for tripId: UUID) async throws -> [TravelDocument] {
        fetchTripCount += 1
        if let fetchError { throw fetchError }
        return storage.values
            .filter { $0.tripId == tripId }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func fetchDocuments(forItemId itemId: UUID) async throws -> [TravelDocument] {
        fetchItemCount += 1
        if let fetchError { throw fetchError }
        return storage.values
            .filter { $0.itineraryItemId == itemId }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func document(with id: UUID) async throws -> TravelDocument? {
        storage[id]
    }

    func createDocument(_ document: TravelDocument) async throws {
        createCallCount += 1
        if let createError { throw createError }
        guard existingTripIds.contains(document.tripId) else {
            throw DocumentRepositoryError.tripNotFound
        }
        if let itemId = document.itineraryItemId, !existingItemIds.contains(itemId) {
            throw DocumentRepositoryError.itemNotFound
        }
        storage[document.id] = document
    }

    func updateDocument(_ document: TravelDocument) async throws {
        updateCallCount += 1
        if let updateError { throw updateError }
        guard storage[document.id] != nil else {
            throw DocumentRepositoryError.notFound
        }
        if let itemId = document.itineraryItemId, !existingItemIds.contains(itemId) {
            throw DocumentRepositoryError.itemNotFound
        }
        storage[document.id] = document
    }

    func deleteDocument(id: UUID) async throws {
        deleteCallCount += 1
        if let deleteError { throw deleteError }
        storage.removeValue(forKey: id)
    }
}
