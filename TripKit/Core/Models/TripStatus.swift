import Foundation

enum TripStatus: String, Hashable {
    case upcoming
    case active
    case past

    var displayName: String {
        switch self {
        case .upcoming: return "Upcoming"
        case .active: return "Active"
        case .past: return "Past"
        }
    }
}
