import SwiftUI

struct TripListView: View {
    @StateObject private var viewModel: TripListViewModel
    @ObservedObject private var appRouter: AppRouter
    private let tripRepository: TripRepository
    private let itineraryRepository: ItineraryRepository
    private let notificationService: NotificationSchedulingService
    private let documentRepository: DocumentRepository
    private let documentStorage: DocumentStorageService
    private let settingsStore: SettingsStore
    private let locationActions: LocationActionService

    @State private var navigationPath = NavigationPath()
    @State private var isCreating = false
    @State private var tripPendingDeletion: Trip?

    init(
        tripRepository: TripRepository,
        itineraryRepository: ItineraryRepository,
        notificationService: NotificationSchedulingService,
        documentRepository: DocumentRepository,
        documentStorage: DocumentStorageService,
        settingsStore: SettingsStore,
        locationActions: LocationActionService,
        appRouter: AppRouter
    ) {
        self.tripRepository = tripRepository
        self.itineraryRepository = itineraryRepository
        self.notificationService = notificationService
        self.documentRepository = documentRepository
        self.documentStorage = documentStorage
        self.settingsStore = settingsStore
        self.locationActions = locationActions
        self.appRouter = appRouter
        _viewModel = StateObject(
            wrappedValue: TripListViewModel(
                repository: tripRepository,
                notificationService: notificationService,
                documentRepository: documentRepository,
                documentStorage: documentStorage
            )
        )
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                TKBackground()
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Trips")
            .navigationDestination(for: TripDestination.self) { destination in
                TripDetailView(
                    trip: destination.trip,
                    focusItemId: destination.focusItemId,
                    itineraryRepository: itineraryRepository,
                    tripRepository: tripRepository,
                    notificationService: notificationService,
                    documentRepository: documentRepository,
                    documentStorage: documentStorage,
                    settingsStore: settingsStore,
                    locationActions: locationActions,
                    onChange: { Task { await viewModel.load() } }
                )
            }
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
                        repository: tripRepository,
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
            .onChange(of: appRouter.pendingTripDetail, initial: true) { _, newRoute in
                guard let newRoute else { return }
                Task { await handlePendingRoute(newRoute) }
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
            .alert(
                "Delete Trip?",
                isPresented: Binding(
                    get: { tripPendingDeletion != nil },
                    set: { if !$0 { tripPendingDeletion = nil } }
                )
            ) {
                Button("Delete Trip", role: .destructive) {
                    if let trip = tripPendingDeletion {
                        Task { await viewModel.delete(trip) }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete the trip, itinerary items, reminders, and attached documents. This cannot be undone.")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.trips.isEmpty {
            ProgressView()
        } else if viewModel.trips.isEmpty {
            TKEmptyStateView(
                systemImage: "suitcase",
                title: "No trips yet",
                message: "Plan your next trip and keep flights, hotels, and activities together, even when you're offline.",
                actionTitle: "Plan your first trip",
                actionSystemImage: "airplane.departure",
                action: { isCreating = true }
            )
        } else {
            tripList
        }
    }

    private var tripList: some View {
        List {
            if !viewModel.upcomingTrips.isEmpty {
                Section {
                    ForEach(viewModel.upcomingTrips) { trip in
                        NavigationLink(value: TripDestination(trip: trip)) {
                            TripRow(trip: trip)
                        }
                    }
                    .onDelete { indexSet in
                        // Swipe-to-delete fires one index in practice; stage
                        // the trip for confirmation rather than deleting it
                        // immediately so the user has a chance to back out
                        // before the cascade runs.
                        if let first = indexSet.first {
                            tripPendingDeletion = viewModel.upcomingTrips[first]
                        }
                    }
                } header: {
                    sectionHeader("Upcoming", systemImage: "airplane.departure")
                }
            }

            if !viewModel.pastTrips.isEmpty {
                Section {
                    ForEach(viewModel.pastTrips) { trip in
                        NavigationLink(value: TripDestination(trip: trip)) {
                            TripRow(trip: trip)
                        }
                    }
                    .onDelete { indexSet in
                        if let first = indexSet.first {
                            tripPendingDeletion = viewModel.pastTrips[first]
                        }
                    }
                } header: {
                    sectionHeader("Past", systemImage: "clock.arrow.circlepath")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(TKTypography.sectionHeader)
            .foregroundStyle(TKColors.textSecondary)
            .textCase(nil)
    }

    private func handlePendingRoute(_ route: PendingTripRoute) async {
        if let trip = try? await tripRepository.trip(with: route.tripId) {
            navigationPath = NavigationPath()
            navigationPath.append(TripDestination(trip: trip, focusItemId: route.itemId))
        }
        // Whether or not the trip resolved, clear the pending route so we don't
        // keep trying. If the trip no longer exists, the user stays on the list.
        appRouter.pendingTripDetail = nil
    }
}

private struct TripRow: View {
    let trip: Trip

    private var status: TripStatus { trip.status() }

    var body: some View {
        HStack(alignment: .top, spacing: TKSpacing.md) {
            VStack(alignment: .leading, spacing: TKSpacing.xs) {
                Text(trip.title)
                    .font(TKTypography.cardTitle)
                    .foregroundStyle(TKColors.textPrimary)
                    .lineLimit(2)

                // Tight HStack instead of `Label` so the pin and destination
                // read as one cohesive metadata row at this font size.
                HStack(spacing: TKSpacing.xs) {
                    Image(systemName: "mappin.and.ellipse")
                        .accessibilityHidden(true)
                    Text(trip.destination)
                }
                .font(TKTypography.cardSubtitle)
                .foregroundStyle(TKColors.textSecondary)
                .lineLimit(1)

                HStack(spacing: TKSpacing.sm) {
                    Text(TripDateFormatter.dateRange(from: trip.startDate, to: trip.endDate))
                        .font(TKTypography.metadata)
                        .foregroundStyle(TKColors.textSecondary)

                    TKBadge(text: status.displayName, color: TKColors.status(status))
                }
                .padding(.top, TKSpacing.xs)
            }

            Spacer(minLength: 0)

            if let trailing = trailingDescriptor {
                Text(trailing)
                    .font(TKTypography.metadataEmphasized)
                    .foregroundStyle(TKColors.status(status))
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(.vertical, TKSpacing.xs)
    }

    private var trailingDescriptor: String? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        switch status {
        case .upcoming:
            let start = calendar.startOfDay(for: trip.startDate)
            guard let days = calendar.dateComponents([.day], from: today, to: start).day, days > 0 else {
                return nil
            }
            return days == 1 ? "in 1 day" : "in \(days) days"
        case .active:
            return "Now"
        case .past:
            let end = calendar.startOfDay(for: trip.endDate)
            guard let days = calendar.dateComponents([.day], from: end, to: today).day, days > 0 else {
                return nil
            }
            return days == 1 ? "1 day ago" : "\(days) days ago"
        }
    }
}

#if DEBUG
#Preview("With trips") {
    let stack = CoreDataStack.previewSeeded()
    TripListView(
        tripRepository: CoreDataTripRepository(stack: stack),
        itineraryRepository: CoreDataItineraryRepository(stack: stack),
        notificationService: UserNotificationSchedulingService(),
        documentRepository: CoreDataDocumentRepository(stack: stack),
        documentStorage: FileManagerDocumentStorageService(),
        settingsStore: UserDefaultsSettingsStore(defaults: UserDefaults(suiteName: "TripKite-Preview")!),
        locationActions: SystemLocationActionService(),
        appRouter: AppRouter()
    )
}

#Preview("Empty") {
    let stack = CoreDataStack(inMemory: true)
    TripListView(
        tripRepository: CoreDataTripRepository(stack: stack),
        itineraryRepository: CoreDataItineraryRepository(stack: stack),
        notificationService: UserNotificationSchedulingService(),
        documentRepository: CoreDataDocumentRepository(stack: stack),
        documentStorage: FileManagerDocumentStorageService(),
        settingsStore: UserDefaultsSettingsStore(defaults: UserDefaults(suiteName: "TripKite-Preview")!),
        locationActions: SystemLocationActionService(),
        appRouter: AppRouter()
    )
}
#endif
