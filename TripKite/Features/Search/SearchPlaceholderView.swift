import SwiftUI

// V2.1 placeholder. The full search experience — substring matching across
// trips, itinerary items, and documents, plus type and status filters — lands
// in V2.4 behind a `SearchService` protocol. This screen exists now so the tab
// shell ships with all four tabs in place.
struct SearchPlaceholderView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                TKBackground()
                TKEmptyStateView(
                    systemImage: "magnifyingglass",
                    title: "Search across your trips",
                    message: "Find a flight by confirmation number, a hotel by city, or a screenshot by name. Search will span every trip, itinerary item, and document."
                )
            }
            .navigationTitle("Search")
        }
    }
}

#if DEBUG
#Preview {
    SearchPlaceholderView()
}
#endif
