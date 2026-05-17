import SwiftUI

enum TKColors {
    static let brand: Color = .accentColor
    static let surface: Color = Color(.systemBackground)
    static let surfaceElevated: Color = Color(.secondarySystemBackground)
    static let surfaceMuted: Color = Color(.tertiarySystemBackground)
    static let textPrimary: Color = .primary
    static let textSecondary: Color = .secondary
    static let divider: Color = Color(.separator)

    static func status(_ status: TripStatus) -> Color {
        switch status {
        case .upcoming: return .blue
        case .active: return .green
        case .past: return .gray
        }
    }

    static func itinerary(_ type: ItineraryType) -> Color {
        switch type {
        case .flight: return .blue
        case .hotel: return .purple
        case .activity: return .orange
        case .restaurant: return .pink
        case .transportation: return .teal
        case .note: return .gray
        case .other: return .gray
        }
    }
}
