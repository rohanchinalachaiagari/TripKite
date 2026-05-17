import SwiftUI

struct TripDetailView: View {
    @State private var trip: Trip
    let itineraryItems: [ItineraryItem]
    private let repository: TripRepository
    private let onChange: () -> Void

    @State private var isEditing = false

    init(
        trip: Trip,
        itineraryItems: [ItineraryItem],
        repository: TripRepository,
        onChange: @escaping () -> Void
    ) {
        _trip = State(initialValue: trip)
        self.itineraryItems = itineraryItems
        self.repository = repository
        self.onChange = onChange
    }

    var body: some View {
        List {
            Section {
                header
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            if !trip.notes.isEmpty {
                Section("Notes") {
                    Text(trip.notes)
                        .font(.body)
                }
            }

            ItineraryTimelineView(items: itineraryItems)
        }
        .listStyle(.insetGrouped)
        .navigationTitle(trip.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { isEditing = true }
            }
        }
        .sheet(isPresented: $isEditing) {
            NavigationStack {
                TripEditorView(
                    mode: .edit(trip),
                    repository: repository,
                    onSaved: {
                        Task {
                            if let updated = try? await repository.trip(with: trip.id) {
                                trip = updated
                            }
                            onChange()
                        }
                    }
                )
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(trip.destination)
                .font(.title2.weight(.semibold))
            Text(TripDateFormatter.dateRange(from: trip.startDate, to: trip.endDate))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            statusBadge
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var statusBadge: some View {
        Text(trip.status().displayName)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.accentColor.opacity(0.2), in: Capsule())
            .foregroundStyle(Color.accentColor)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        TripDetailView(
            trip: MockData.tokyoTrip,
            itineraryItems: MockData.tokyoItinerary,
            repository: CoreDataTripRepository(stack: .previewSeeded()),
            onChange: {}
        )
    }
}
#endif
