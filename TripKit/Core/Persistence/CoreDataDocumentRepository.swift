import CoreData
import Foundation

nonisolated final class CoreDataDocumentRepository: DocumentRepository, @unchecked Sendable {
    private let stack: CoreDataStack

    init(stack: CoreDataStack) {
        self.stack = stack
    }

    func fetchDocuments(for tripId: UUID) async throws -> [TravelDocument] {
        let context = stack.newBackgroundContext()
        return try await context.perform {
            let request = NSFetchRequest<TravelDocumentEntity>(entityName: "TravelDocumentEntity")
            request.predicate = NSPredicate(format: "trip.id == %@", tripId as CVarArg)
            request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
            return try context.fetch(request).map { $0.toDomain() }
        }
    }

    func fetchDocuments(forItemId itemId: UUID) async throws -> [TravelDocument] {
        let context = stack.newBackgroundContext()
        return try await context.perform {
            let request = NSFetchRequest<TravelDocumentEntity>(entityName: "TravelDocumentEntity")
            request.predicate = NSPredicate(format: "item.id == %@", itemId as CVarArg)
            request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
            return try context.fetch(request).map { $0.toDomain() }
        }
    }

    func document(with id: UUID) async throws -> TravelDocument? {
        let context = stack.newBackgroundContext()
        return try await context.perform {
            try Self.fetchDocumentEntity(with: id, in: context)?.toDomain()
        }
    }

    func createDocument(_ document: TravelDocument) async throws {
        let context = stack.newBackgroundContext()
        try await context.perform {
            guard let tripEntity = try Self.fetchTripEntity(with: document.tripId, in: context) else {
                throw DocumentRepositoryError.tripNotFound
            }
            var itemEntity: ItineraryItemEntity?
            if let itemId = document.itineraryItemId {
                guard let found = try Self.fetchItemEntity(with: itemId, in: context) else {
                    throw DocumentRepositoryError.itemNotFound
                }
                itemEntity = found
            }
            let entity = TravelDocumentEntity(context: context)
            entity.apply(document)
            entity.trip = tripEntity
            entity.item = itemEntity
            try context.save()
        }
    }

    func updateDocument(_ document: TravelDocument) async throws {
        let context = stack.newBackgroundContext()
        try await context.perform {
            guard let entity = try Self.fetchDocumentEntity(with: document.id, in: context) else {
                throw DocumentRepositoryError.notFound
            }
            // Only scalar metadata is rewritten. The trip/item relationships
            // and `localRelativePath` aren't moved — rename never touches the
            // file on disk.
            entity.apply(document)
            try context.save()
        }
    }

    func deleteDocument(id: UUID) async throws {
        let context = stack.newBackgroundContext()
        try await context.perform {
            guard let entity = try Self.fetchDocumentEntity(with: id, in: context) else {
                return
            }
            context.delete(entity)
            try context.save()
        }
    }

    private static func fetchDocumentEntity(with id: UUID, in context: NSManagedObjectContext) throws -> TravelDocumentEntity? {
        let request = NSFetchRequest<TravelDocumentEntity>(entityName: "TravelDocumentEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private static func fetchTripEntity(with id: UUID, in context: NSManagedObjectContext) throws -> TripEntity? {
        let request = NSFetchRequest<TripEntity>(entityName: "TripEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private static func fetchItemEntity(with id: UUID, in context: NSManagedObjectContext) throws -> ItineraryItemEntity? {
        let request = NSFetchRequest<ItineraryItemEntity>(entityName: "ItineraryItemEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }
}
