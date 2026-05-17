import SwiftUI

@main
struct TripKitApp: App {
    private let tripRepository: TripRepository
    private let itineraryRepository: ItineraryRepository

    init() {
        let stack = CoreDataStack()
        self.tripRepository = CoreDataTripRepository(stack: stack)
        self.itineraryRepository = CoreDataItineraryRepository(stack: stack)
    }

    var body: some Scene {
        WindowGroup {
            TripListView(
                tripRepository: tripRepository,
                itineraryRepository: itineraryRepository
            )
        }
    }
}
