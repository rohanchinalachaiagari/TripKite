import Foundation

struct ItineraryItem: Identifiable, Hashable {
    let id: UUID
    var tripId: UUID
    var title: String
    var type: ItineraryType
    var startDate: Date
    var endDate: Date?
    var locationName: String
    var address: String
    var confirmationNumber: String
    var notes: String
    var reminderOffset: TimeInterval?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        tripId: UUID,
        title: String,
        type: ItineraryType,
        startDate: Date,
        endDate: Date? = nil,
        locationName: String = "",
        address: String = "",
        confirmationNumber: String = "",
        notes: String = "",
        reminderOffset: TimeInterval? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.tripId = tripId
        self.title = title
        self.type = type
        self.startDate = startDate
        self.endDate = endDate
        self.locationName = locationName
        self.address = address
        self.confirmationNumber = confirmationNumber
        self.notes = notes
        self.reminderOffset = reminderOffset
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
