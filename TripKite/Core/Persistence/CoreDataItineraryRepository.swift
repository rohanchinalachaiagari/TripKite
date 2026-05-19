import CoreData
import Foundation

nonisolated final class CoreDataItineraryRepository: ItineraryRepository, @unchecked Sendable {
    private let stack: CoreDataStack

    init(stack: CoreDataStack) {
        self.stack = stack
    }

    func fetchItems(for tripId: UUID) async throws -> [ItineraryItem] {
        let context = stack.newBackgroundContext()
        return try await context.perform {
            let request = NSFetchRequest<ItineraryItemEntity>(entityName: "ItineraryItemEntity")
            request.predicate = NSPredicate(format: "trip.id == %@", tripId as CVarArg)
            request.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: true)]
            let entities = try context.fetch(request)
            return entities.map { $0.toDomain() }
        }
    }

    func item(with id: UUID) async throws -> ItineraryItem? {
        let context = stack.newBackgroundContext()
        return try await context.perform {
            try Self.fetchItemEntity(with: id, in: context)?.toDomain()
        }
    }

    func createItem(_ item: ItineraryItem) async throws {
        let context = stack.newBackgroundContext()
        try await context.perform {
            guard let tripEntity = try Self.fetchTripEntity(with: item.tripId, in: context) else {
                throw ItineraryRepositoryError.tripNotFound
            }
            let entity = ItineraryItemEntity(context: context)
            entity.apply(item)
            entity.trip = tripEntity
            try context.save()
        }
    }

    func updateItem(_ item: ItineraryItem) async throws {
        let context = stack.newBackgroundContext()
        try await context.perform {
            guard let entity = try Self.fetchItemEntity(with: item.id, in: context) else {
                throw ItineraryRepositoryError.notFound
            }
            entity.apply(item)
            try context.save()
        }
    }

    func deleteItem(id: UUID) async throws {
        let context = stack.newBackgroundContext()
        try await context.perform {
            guard let entity = try Self.fetchItemEntity(with: id, in: context) else {
                return
            }
            context.delete(entity)
            try context.save()
        }
    }

    private static func fetchItemEntity(with id: UUID, in context: NSManagedObjectContext) throws -> ItineraryItemEntity? {
        let request = NSFetchRequest<ItineraryItemEntity>(entityName: "ItineraryItemEntity")
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
}
