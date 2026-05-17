import SwiftUI

@main
struct TripKitApp: App {
    private let tripRepository: TripRepository

    init() {
        let stack = CoreDataStack()
        self.tripRepository = CoreDataTripRepository(stack: stack)
    }

    var body: some Scene {
        WindowGroup {
            TripListView(repository: tripRepository)
        }
    }
}
