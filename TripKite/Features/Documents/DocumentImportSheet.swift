import SwiftUI

// Modal form that collects the trip (required) and optional itinerary-item
// association for an in-flight import. Presented by DocumentVaultView when
// `pendingImport` becomes non-nil. The view doesn't own the staged file or
// trigger the save — it just collects user choices and delegates.
struct DocumentImportSheet: View {
    let trips: [Trip]
    let itemsByTripId: [UUID: [ItineraryItem]]
    let isAttaching: Bool
    let onConfirm: (UUID, UUID?) -> Void
    let onCancel: () -> Void

    @State private var selectedTripId: UUID?
    @State private var selectedItemId: UUID?

    private var itemsForSelectedTrip: [ItineraryItem] {
        guard let tripId = selectedTripId else { return [] }
        return itemsByTripId[tripId] ?? []
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Trip", selection: $selectedTripId) {
                        Text("Select a trip").tag(UUID?.none)
                        ForEach(sortedTrips) { trip in
                            Text(trip.title).tag(UUID?.some(trip.id))
                        }
                    }
                } header: {
                    Text("Trip")
                } footer: {
                    Text("Documents in the vault belong to a trip.")
                }

                if !itemsForSelectedTrip.isEmpty {
                    Section {
                        Picker("Attached to", selection: $selectedItemId) {
                            Text("Entire trip").tag(UUID?.none)
                            ForEach(itemsForSelectedTrip) { item in
                                Text(item.title).tag(UUID?.some(item.id))
                            }
                        }
                    } header: {
                        Text("Attached to")
                    } footer: {
                        Text("Optionally pin this document to a specific item on the trip.")
                    }
                }
            }
            .navigationTitle("Add Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { onCancel() }
                        .disabled(isAttaching)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        if let tripId = selectedTripId {
                            onConfirm(tripId, selectedItemId)
                        }
                    }
                    .disabled(selectedTripId == nil || isAttaching)
                }
            }
            .onChange(of: selectedTripId) { _, _ in
                // Reset item selection when trip changes — the previously
                // selected item id is not valid for the new trip.
                selectedItemId = nil
            }
        }
        .interactiveDismissDisabled(isAttaching)
    }

    private var sortedTrips: [Trip] {
        trips.sorted { $0.startDate < $1.startDate }
    }
}

#if DEBUG
#Preview {
    DocumentImportSheet(
        trips: MockData.trips,
        itemsByTripId: Dictionary(grouping: MockData.allItineraryItems, by: \.tripId),
        isAttaching: false,
        onConfirm: { _, _ in },
        onCancel: {}
    )
}
#endif
