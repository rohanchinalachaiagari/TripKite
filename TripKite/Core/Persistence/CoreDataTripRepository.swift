import CoreData
import Foundation

nonisolated final class CoreDataTripRepository: TripRepository, @unchecked Sendable {
    private let stack: CoreDataStack

    init(stack: CoreDataStack) {
        self.stack = stack
    }

    func fetchTrips() async throws -> [Trip] {
        let context = stack.newBackgroundContext()
        return try await context.perform {
            let request = NSFetchRequest<TripEntity>(entityName: "TripEntity")
            request.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: true)]
            let entities = try context.fetch(request)
            return entities.map { $0.toDomain() }
        }
    }

    func trip(with id: UUID) async throws -> Trip? {
        let context = stack.newBackgroundContext()
        return try await context.perform {
            try Self.fetchEntity(with: id, in: context)?.toDomain()
        }
    }

    func createTrip(_ trip: Trip) async throws {
        let context = stack.newBackgroundContext()
        try await context.perform {
            let entity = TripEntity(context: context)
            entity.apply(trip)
            try context.save()
        }
    }

    func updateTrip(_ trip: Trip) async throws {
        let context = stack.newBackgroundContext()
        try await context.perform {
            guard let entity = try Self.fetchEntity(with: trip.id, in: context) else {
                throw TripRepositoryError.notFound
            }
            entity.apply(trip)
            try context.save()
        }
    }

    func deleteTrip(id: UUID) async throws {
        let context = stack.newBackgroundContext()
        try await context.perform {
            guard let entity = try Self.fetchEntity(with: id, in: context) else {
                return
            }
            context.delete(entity)
            try context.save()
        }
    }

    private static func fetchEntity(with id: UUID, in context: NSManagedObjectContext) throws -> TripEntity? {
        let request = NSFetchRequest<TripEntity>(entityName: "TripEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }
}
