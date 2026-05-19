import Foundation

enum TripDateFormatter {
    static func dateRange(from start: Date, to end: Date) -> String {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: start, to: end) ?? ""
    }

    static func mediumDate(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day().year())
    }

    static func dayHeader(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    static func timeOfDay(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute())
    }

    static func timeRange(start: Date, end: Date?) -> String {
        guard let end else { return timeOfDay(start) }
        return "\(timeOfDay(start)) – \(timeOfDay(end))"
    }
}
