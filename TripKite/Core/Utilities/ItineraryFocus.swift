import Foundation

enum ItineraryFocus: Equatable {
    case happeningNow(ItineraryItem)
    case upNext(ItineraryItem)

    var item: ItineraryItem {
        switch self {
        case .happeningNow(let item), .upNext(let item):
            return item
        }
    }
}

enum ItineraryFocusResolver {
    // Items without an explicit endDate are treated as active for this many seconds
    // after their startDate. Two hours is a heuristic that covers typical "point"
    // items (restaurant reservations, short stops, notes).
    static let defaultPointDuration: TimeInterval = 2 * 60 * 60

    static func resolve(
        items: [ItineraryItem],
        now: Date,
        pointDuration: TimeInterval = defaultPointDuration
    ) -> ItineraryFocus? {
        let active = items.filter { item in
            let effectiveEnd = item.endDate ?? item.startDate.addingTimeInterval(pointDuration)
            return item.startDate <= now && effectiveEnd >= now
        }

        if !active.isEmpty {
            let chosen = active.max { lhs, rhs in
                if lhs.startDate != rhs.startDate {
                    return lhs.startDate < rhs.startDate
                }
                return lhs.createdAt > rhs.createdAt
            }
            return chosen.map(ItineraryFocus.happeningNow)
        }

        let upcoming = items
            .filter { $0.startDate > now }
            .min { lhs, rhs in
                if lhs.startDate != rhs.startDate {
                    return lhs.startDate < rhs.startDate
                }
                return lhs.createdAt < rhs.createdAt
            }

        return upcoming.map(ItineraryFocus.upNext)
    }
}
