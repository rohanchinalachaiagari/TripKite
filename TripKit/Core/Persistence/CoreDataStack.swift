import CoreData
import Foundation

nonisolated final class CoreDataStack: @unchecked Sendable {
    static let modelName = "TripKit"

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: Self.modelName)

        if inMemory, let description = container.persistentStoreDescriptions.first {
            description.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { _, error in
            if let error {
                assertionFailure("Failed to load persistent store: \(error)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    var viewContext: NSManagedObjectContext { container.viewContext }

    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
}

#if DEBUG
extension CoreDataStack {
    static func previewSeeded() -> CoreDataStack {
        let stack = CoreDataStack(inMemory: true)
        let context = stack.viewContext
        for trip in MockData.trips {
            let entity = TripEntity(context: context)
            entity.apply(trip)
        }
        try? context.save()
        return stack
    }
}
#endif
