import CoreData
import Foundation

extension ItineraryItemEntity {
    func toDomain() -> ItineraryItem {
        ItineraryItem(
            id: id ?? UUID(),
            tripId: trip?.id ?? UUID(),
            title: title ?? "",
            type: ItineraryType(rawValue: typeRaw ?? "") ?? .other,
            startDate: startDate ?? Date(),
            endDate: endDate,
            locationName: locationName ?? "",
            address: address ?? "",
            confirmationNumber: confirmationNumber ?? "",
            notes: notes ?? "",
            createdAt: createdAt ?? Date(),
            updatedAt: updatedAt ?? Date()
        )
    }

    // The `trip` relationship is intentionally left untouched. Callers are
    // responsible for assigning the parent TripEntity when creating a new item.
    func apply(_ item: ItineraryItem) {
        id = item.id
        title = item.title
        typeRaw = item.type.rawValue
        startDate = item.startDate
        endDate = item.endDate
        locationName = item.locationName
        address = item.address
        confirmationNumber = item.confirmationNumber
        notes = item.notes
        createdAt = item.createdAt
        updatedAt = item.updatedAt
    }
}
