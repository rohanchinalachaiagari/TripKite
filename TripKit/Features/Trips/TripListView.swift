import SwiftUI

struct TripListView: View {
    let trips: [Trip]

    @State private var isCreating = false

    private var upcomingTrips: [Trip] {
        trips
            .filter { $0.status() != .past }
            .sorted { $0.startDate < $1.startDate }
    }

    private var pastTrips: [Trip] {
        trips
            .filter { $0.status() == .past }
            .sorted { $0.startDate > $1.startDate }
    }

    var body: some View {
        NavigationStack {
            Group {
                if trips.isEmpty {
                    emptyState
                } else {
                    tripList
                }
            }
            .navigationTitle("Trips")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isCreating = true
                    } label: {
                        Label("New Trip", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isCreating) {
                NavigationStack {
                    TripEditorView(mode: .create)
                }
            }
        }
    }

    private var tripList: some View {
        List {
            if !upcomingTrips.isEmpty {
                Section("Upcoming") {
                    ForEach(upcomingTrips) { trip in
                        tripLink(for: trip)
                    }
                }
            }

            if !pastTrips.isEmpty {
                Section("Past") {
                    ForEach(pastTrips) { trip in
                        tripLink(for: trip)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func tripLink(for trip: Trip) -> some View {
        NavigationLink {
            TripDetailView(
                trip: trip,
                itineraryItems: MockData.itineraryItems(for: trip)
            )
        } label: {
            TripRow(trip: trip)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "suitcase")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No trips yet")
                .font(.title3.weight(.semibold))
            Text("Tap the + button to plan your first trip.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

private struct TripRow: View {
    let trip: Trip

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(trip.title)
                .font(.headline)
            Text(trip.destination)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(TripDateFormatter.dateRange(from: trip.startDate, to: trip.endDate))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview("With trips") {
    TripListView(trips: MockData.trips)
}

#Preview("Empty") {
    TripListView(trips: [])
}
