import Foundation
import Combine

struct PendingTripRoute: Equatable, Hashable, Sendable {
    let tripId: UUID
    let itemId: UUID?
}

@MainActor
final class AppRouter: ObservableObject {
    @Published var pendingTripDetail: PendingTripRoute?
}
