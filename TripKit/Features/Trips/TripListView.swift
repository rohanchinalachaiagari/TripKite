import SwiftUI

struct TripListView: View {
    @StateObject private var viewModel: TripListViewModel
    private let repository: TripRepository

    @State private var isCreating = false

    init(repository: TripRepository) {
        self.repository = repository
        _viewModel = StateObject(wrappedValue: TripListViewModel(repository: repository))
    }

    var body: some View {
        NavigationStack {
            content
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
                        TripEditorView(
                            mode: .create,
                            repository: repository,
                            onSaved: { Task { await viewModel.load() } }
                        )
                    }
                }
                .task {
                    if viewModel.trips.isEmpty {
                        await viewModel.load()
                    }
                }
                .refreshable {
                    await viewModel.load()
                }
                .alert(
                    "Something went wrong",
                    isPresented: Binding(
                        get: { viewModel.errorMessage != nil },
                        set: { if !$0 { viewModel.errorMessage = nil } }
                    ),
                    presenting: viewModel.errorMessage
                ) { _ in
                    Button("OK", role: .cancel) { viewModel.errorMessage = nil }
                } message: { message in
                    Text(message)
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.trips.isEmpty {
            ProgressView()
        } else if viewModel.trips.isEmpty {
            emptyState
        } else {
            tripList
        }
    }

    private var tripList: some View {
        List {
            if !viewModel.upcomingTrips.isEmpty {
                Section("Upcoming") {
                    ForEach(viewModel.upcomingTrips) { trip in
                        tripLink(for: trip)
                    }
                    .onDelete { indexSet in
                        let toDelete = indexSet.map { viewModel.upcomingTrips[$0] }
                        Task {
                            for trip in toDelete {
                                await viewModel.delete(trip)
                            }
                        }
                    }
                }
            }

            if !viewModel.pastTrips.isEmpty {
                Section("Past") {
                    ForEach(viewModel.pastTrips) { trip in
                        tripLink(for: trip)
                    }
                    .onDelete { indexSet in
                        let toDelete = indexSet.map { viewModel.pastTrips[$0] }
                        Task {
                            for trip in toDelete {
                                await viewModel.delete(trip)
                            }
                        }
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
                itineraryItems: MockData.itineraryItems(for: trip),
                repository: repository,
                onChange: { Task { await viewModel.load() } }
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

#if DEBUG
#Preview("With trips") {
    TripListView(repository: CoreDataTripRepository(stack: .previewSeeded()))
}

#Preview("Empty") {
    TripListView(repository: CoreDataTripRepository(stack: CoreDataStack(inMemory: true)))
}
#endif
