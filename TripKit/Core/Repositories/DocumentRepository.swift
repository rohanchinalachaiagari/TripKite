import Foundation

protocol DocumentRepository: Sendable {
    func fetchDocuments(for tripId: UUID) async throws -> [TravelDocument]
    func fetchDocuments(forItemId itemId: UUID) async throws -> [TravelDocument]
    func document(with id: UUID) async throws -> TravelDocument?
    func createDocument(_ document: TravelDocument) async throws
    func updateDocument(_ document: TravelDocument) async throws
    func deleteDocument(id: UUID) async throws
}

enum DocumentRepositoryError: LocalizedError, Equatable {
    case notFound
    case tripNotFound
    case itemNotFound

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Document not found."
        case .tripNotFound:
            return "Couldn't find the trip for this document."
        case .itemNotFound:
            return "Couldn't find the itinerary item for this document."
        }
    }
}
