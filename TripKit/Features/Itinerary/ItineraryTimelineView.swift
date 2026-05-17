import SwiftUI

struct ItineraryTimelineView: View {
    let items: [ItineraryItem]

    private var groupedByDay: [(day: Date, items: [ItineraryItem])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: items.sorted(by: { $0.startDate < $1.startDate })) { item in
            calendar.startOfDay(for: item.startDate)
        }
        return grouped
            .map { (day: $0.key, items: $0.value) }
            .sorted { $0.day < $1.day }
    }

    var body: some View {
        if items.isEmpty {
            emptyState
        } else {
            ForEach(groupedByDay, id: \.day) { group in
                Section {
                    ForEach(group.items) { item in
                        ItineraryItemRow(item: item)
                    }
                } header: {
                    Text(TripDateFormatter.dayHeader(group.day))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.plus")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No itinerary items yet")
                .font(.headline)
            Text("Add flights, hotels, and activities to build your trip timeline.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

#Preview("With items") {
    List {
        ItineraryTimelineView(items: MockData.tokyoItinerary)
    }
}

#Preview("Empty") {
    List {
        ItineraryTimelineView(items: [])
    }
}
