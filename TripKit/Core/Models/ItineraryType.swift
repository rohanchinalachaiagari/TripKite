import Foundation

enum ItineraryType: String, CaseIterable, Identifiable, Codable, Hashable {
    case flight
    case hotel
    case activity
    case restaurant
    case transportation
    case note
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .flight: return "Flight"
        case .hotel: return "Hotel"
        case .activity: return "Activity"
        case .restaurant: return "Restaurant"
        case .transportation: return "Transportation"
        case .note: return "Note"
        case .other: return "Other"
        }
    }

    var systemImageName: String {
        switch self {
        case .flight: return "airplane"
        case .hotel: return "bed.double.fill"
        case .activity: return "figure.walk"
        case .restaurant: return "fork.knife"
        case .transportation: return "car.fill"
        case .note: return "note.text"
        case .other: return "mappin.and.ellipse"
        }
    }
}
