import SwiftUI

@main
struct TripKitApp: App {
    var body: some Scene {
        WindowGroup {
            TripListView(trips: MockData.trips)
        }
    }
}
