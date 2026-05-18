import Foundation
import Combine

struct PendingTripRoute: Equatable, Hashable, Sendable {
    let tripId: UUID
    let itemId: UUID?
}

// Navigation value pushed onto the trip list's NavigationStack. Carries an
// optional itineraryItemId so a notification tap can deep-link past the trip
// to a specific item — `TripDetailView` opens the editor for it once items
// have loaded.
struct TripDestination: Hashable, Sendable {
    let trip: Trip
    let focusItemId: UUID?

    init(trip: Trip, focusItemId: UUID? = nil) {
        self.trip = trip
        self.focusItemId = focusItemId
    }
}

@MainActor
final class AppRouter: ObservableObject {
    @Published var pendingTripDetail: PendingTripRoute?
}
