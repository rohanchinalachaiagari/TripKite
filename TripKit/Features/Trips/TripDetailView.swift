import SwiftUI

struct TripDetailView: View {
    @StateObject private var viewModel: TripDetailViewModel
    private let itineraryRepository: ItineraryRepository
    private let tripRepository: TripRepository
    private let onChange: () -> Void

    @State private var isEditingTrip = false
    @State private var isCreatingItem = false
    @State private var editingItem: ItineraryItem?

    init(
        trip: Trip,
        itineraryRepository: ItineraryRepository,
        tripRepository: TripRepository,
        onChange: @escaping () -> Void
    ) {
        self.itineraryRepository = itineraryRepository
        self.tripRepository = tripRepository
        self.onChange = onChange
        _viewModel = StateObject(
            wrappedValue: TripDetailViewModel(
                trip: trip,
                itineraryRepository: itineraryRepository,
                tripRepository: tripRepository
            )
        )
    }

    var body: some View {
        ZStack {
            TKBackground()
            List {
                Section {
                    header
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                if !viewModel.trip.notes.isEmpty {
                    Section {
                        Text(viewModel.trip.notes)
                            .font(TKTypography.body)
                            .foregroundStyle(TKColors.textPrimary)
                    } header: {
                        Label("Notes", systemImage: "note.text")
                            .font(TKTypography.sectionHeader)
                            .foregroundStyle(TKColors.textSecondary)
                            .textCase(nil)
                    }
                }

                ItineraryTimelineView(
                    items: viewModel.items,
                    onSelect: { item in editingItem = item },
                    onDelete: { item in
                        Task { await viewModel.deleteItem(item) }
                    },
                    onAddItem: { isCreatingItem = true }
                )
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(viewModel.trip.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isCreatingItem = true
                } label: {
                    Label("Add Item", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { isEditingTrip = true }
            }
        }
        .task {
            if viewModel.items.isEmpty {
                await viewModel.load()
            }
        }
        .sheet(isPresented: $isEditingTrip) {
            NavigationStack {
                TripEditorView(
                    mode: .edit(viewModel.trip),
                    repository: tripRepository,
                    onSaved: {
                        Task {
                            await viewModel.refreshTrip()
                            onChange()
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $isCreatingItem) {
            NavigationStack {
                ItineraryItemEditorView(
                    mode: .create(
                        tripId: viewModel.trip.id,
                        defaultStartDate: viewModel.trip.startDate
                    ),
                    repository: itineraryRepository,
                    onSaved: {
                        Task { await viewModel.load() }
                    }
                )
            }
        }
        .sheet(item: $editingItem) { item in
            NavigationStack {
                ItineraryItemEditorView(
                    mode: .edit(item),
                    repository: itineraryRepository,
                    onSaved: {
                        Task { await viewModel.load() }
                    }
                )
            }
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

    private var header: some View {
        let status = viewModel.trip.status()
        return VStack(alignment: .leading, spacing: TKSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Label(viewModel.trip.destination, systemImage: "mappin.and.ellipse")
                    .font(TKTypography.heroTitle)
                    .foregroundStyle(TKColors.textPrimary)
                    .lineLimit(2)
                Spacer(minLength: TKSpacing.sm)
                TKBadge(text: status.displayName, color: TKColors.status(status))
            }

            Label(
                TripDateFormatter.dateRange(from: viewModel.trip.startDate, to: viewModel.trip.endDate),
                systemImage: "calendar"
            )
            .font(TKTypography.cardSubtitle)
            .foregroundStyle(TKColors.textSecondary)
        }
        .tkCard(background: TKColors.brand.opacity(0.12))
        .padding(.horizontal, TKSpacing.lg)
        .padding(.top, TKSpacing.sm)
        .padding(.bottom, TKSpacing.xs)
    }
}

#if DEBUG
#Preview {
    let stack = CoreDataStack.previewSeeded()
    NavigationStack {
        TripDetailView(
            trip: MockData.tokyoTrip,
            itineraryRepository: CoreDataItineraryRepository(stack: stack),
            tripRepository: CoreDataTripRepository(stack: stack),
            onChange: {}
        )
    }
}
#endif
