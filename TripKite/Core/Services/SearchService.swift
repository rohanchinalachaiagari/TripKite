import Foundation

struct SearchQuery: Equatable, Sendable {
    let raw: String

    init(_ raw: String) {
        self.raw = raw
    }

    var normalized: String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isEmpty: Bool {
        normalized.isEmpty
    }
}

struct SearchResults: Equatable, Sendable {
    let trips: [Trip]
    let items: [ItineraryItem]
    let documents: [TravelDocument]
    // Lookup table for resolving a result's parent trip when rendering an
    // item / document row. Populated from the trips fetched during the same
    // search call, so a row whose parent trip was deleted simply renders
    // without a parent-trip subtitle rather than throwing.
    let tripsById: [UUID: Trip]

    static let empty = SearchResults(trips: [], items: [], documents: [], tripsById: [:])

    var isEmpty: Bool {
        trips.isEmpty && items.isEmpty && documents.isEmpty
    }
}

protocol SearchService: Sendable {
    func search(_ query: SearchQuery) async throws -> SearchResults
}

// Default offline implementation. Fans out to the three repositories in
// parallel and filters the loaded objects in memory using
// `localizedStandardContains`, which is case- and diacritic-insensitive and
// honors the user's locale. Designed for the V2.4 dataset (a handful of trips,
// dozens of items, a few documents per trip) — there is no on-disk index.
nonisolated final class LocalSearchService: SearchService, @unchecked Sendable {
    private let tripRepository: TripRepository
    private let itineraryRepository: ItineraryRepository
    private let documentRepository: DocumentRepository

    init(
        tripRepository: TripRepository,
        itineraryRepository: ItineraryRepository,
        documentRepository: DocumentRepository
    ) {
        self.tripRepository = tripRepository
        self.itineraryRepository = itineraryRepository
        self.documentRepository = documentRepository
    }

    func search(_ query: SearchQuery) async throws -> SearchResults {
        guard !query.isEmpty else { return .empty }
        let needle = query.normalized

        async let tripsTask = tripRepository.fetchTrips()
        async let itemsTask = itineraryRepository.fetchAllItems()
        async let documentsTask = documentRepository.fetchAllDocuments()

        let allTrips = try await tripsTask
        let allItems = try await itemsTask
        let allDocuments = try await documentsTask

        let matchedTrips = allTrips
            .filter { Self.matches(trip: $0, needle: needle) }
            .sorted { $0.startDate < $1.startDate }

        let matchedItems = allItems
            .filter { Self.matches(item: $0, needle: needle) }
            .sorted { $0.startDate < $1.startDate }

        let matchedDocuments = allDocuments
            .filter { Self.matches(document: $0, needle: needle) }
            .sorted { $0.createdAt > $1.createdAt }

        let tripsById = Dictionary(uniqueKeysWithValues: allTrips.map { ($0.id, $0) })

        return SearchResults(
            trips: matchedTrips,
            items: matchedItems,
            documents: matchedDocuments,
            tripsById: tripsById
        )
    }

    private static func matches(trip: Trip, needle: String) -> Bool {
        contains(trip.title, needle)
            || contains(trip.destination, needle)
            || contains(trip.notes, needle)
    }

    private static func matches(item: ItineraryItem, needle: String) -> Bool {
        contains(item.title, needle)
            || contains(item.type.displayName, needle)
            || contains(item.locationName, needle)
            || contains(item.address, needle)
            || contains(item.confirmationNumber, needle)
            || contains(item.notes, needle)
    }

    private static func matches(document: TravelDocument, needle: String) -> Bool {
        contains(document.fileName, needle)
            || contains(document.fileType, needle)
    }

    private static func contains(_ haystack: String, _ needle: String) -> Bool {
        guard !haystack.isEmpty else { return false }
        return haystack.localizedStandardContains(needle)
    }
}
