import Foundation

struct Trip: Identifiable, Hashable {
    let id: UUID
    var title: String
    var destination: String
    var startDate: Date
    var endDate: Date
    var notes: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        destination: String,
        startDate: Date,
        endDate: Date,
        notes: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.destination = destination
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func status(relativeTo now: Date = Date()) -> TripStatus {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)

        if end < today { return .past }
        if start > today { return .upcoming }
        return .active
    }
}
