import CoreData
import Foundation

extension TripEntity {
    func toDomain() -> Trip {
        Trip(
            id: id ?? UUID(),
            title: title ?? "",
            destination: destination ?? "",
            startDate: startDate ?? Date(),
            endDate: endDate ?? Date(),
            notes: notes ?? "",
            createdAt: createdAt ?? Date(),
            updatedAt: updatedAt ?? Date()
        )
    }

    func apply(_ trip: Trip) {
        id = trip.id
        title = trip.title
        destination = trip.destination
        startDate = trip.startDate
        endDate = trip.endDate
        notes = trip.notes
        createdAt = trip.createdAt
        updatedAt = trip.updatedAt
    }
}
