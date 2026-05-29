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
    // Active section is intentionally not collapsible — it's always at the
    // top so the user sees the trip they're on right now. Upcoming defaults
    // expanded; Past defaults collapsed to keep the list focused.
    @State private var isUpcomingExpanded = true
    @State private var isPastExpanded = false

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

    // V2.8b: dropped `List` for the trip list specifically so we can own the
    // collapse animation. Each section is a custom `tripsSection` view that
    // renders a header plus a card-styled VStack of rows. Rows have an
    // `.asymmetric` transition that combines `.move(edge: .top)` with
    // `.opacity`, and SwiftUI's animation transaction is configured with a
    // per-row delay so the rows cascade out from under the header on expand
    // (and back under on collapse).
    private var tripList: some View {
        ScrollView {
            VStack(spacing: TKSpacing.xl) {
                if !viewModel.activeTrips.isEmpty {
                    tripsSection(
                        title: "Active",
                        systemImage: "location.fill",
                        trips: viewModel.activeTrips,
                        collapseBinding: nil
                    )
                }

                if !viewModel.upcomingTrips.isEmpty {
                    tripsSection(
                        title: "Upcoming",
                        systemImage: "airplane.departure",
                        trips: viewModel.upcomingTrips,
                        collapseBinding: $isUpcomingExpanded
                    )
                }

                if !viewModel.pastTrips.isEmpty {
                    tripsSection(
                        title: "Past",
                        systemImage: "clock.arrow.circlepath",
                        trips: viewModel.pastTrips,
                        collapseBinding: $isPastExpanded
                    )
                }
            }
            .padding(.horizontal, TKSpacing.lg)
            .padding(.vertical, TKSpacing.md)
        }
        .scrollContentBackground(.hidden)
    }

    // collapseBinding == nil  → section is always expanded, no chevron.
    // collapseBinding != nil  → section has a tappable chevron header and
    //                            uses cascadeAnimation for row stagger.
    @ViewBuilder
    private func tripsSection(
        title: String,
        systemImage: String,
        trips: [Trip],
        collapseBinding: Binding<Bool>?
    ) -> some View {
        let isExpanded = collapseBinding?.wrappedValue ?? true

        VStack(alignment: .leading, spacing: TKSpacing.sm) {
            sectionHeaderRow(
                title: title,
                systemImage: systemImage,
                collapseBinding: collapseBinding
            )
            // SwiftUI VStack draws later siblings on top of earlier ones,
            // so without an explicit zIndex the card sits above the header
            // in hit-testing order. During a collapse, a row animating
            // upward passes through the header's region — and the row,
            // being on top, eats the tap. Lifting the header to zIndex 1
            // makes it the topmost view in the section, so taps in the
            // header region always go to the header regardless of what's
            // animating below.
            .zIndex(1)

            // The rounded card sits below the header. Rows inside use a
            // `.move(edge: .top)` transition; `.clipShape` on the card
            // crops anything still above the card's top edge mid-animation
            // so each row visibly emerges from under the section header
            // rather than floating in from above.
            VStack(spacing: 0) {
                ForEach(Array(trips.enumerated()), id: \.element.id) { index, trip in
                    if isExpanded {
                        tripRowLink(for: trip)
                            // Belt-and-suspenders: even though zIndex covers
                            // the header-overlap case, gating hit-testing on
                            // isExpanded also blocks taps on rows mid-fade
                            // anywhere else in the card.
                            .allowsHitTesting(isExpanded)
                            .transition(
                                .asymmetric(
                                    insertion: .move(edge: .top).combined(with: .opacity),
                                    removal: .move(edge: .top).combined(with: .opacity)
                                )
                            )
                            .animation(
                                .smooth(duration: 0.6)
                                    .delay(rowDelay(index: index, total: trips.count, expanding: isExpanded)),
                                value: isExpanded
                            )

                        if index < trips.count - 1 {
                            Divider()
                                .padding(.leading, TKSpacing.lg)
                                .transition(.opacity)
                                .animation(
                                    .smooth(duration: 0.35)
                                        .delay(rowDelay(index: index, total: trips.count, expanding: isExpanded)),
                                    value: isExpanded
                                )
                        }
                    }
                }
            }
            .background(
                TKColors.surfaceElevated.opacity(isExpanded ? 1 : 0),
                in: RoundedRectangle(cornerRadius: TKRadius.medium, style: .continuous)
            )
            .clipShape(RoundedRectangle(cornerRadius: TKRadius.medium, style: .continuous))
            .animation(.smooth(duration: 0.4), value: isExpanded)
        }
    }

    // Stagger delay per row. Expanding: top row first, others cascade in
    // below it. Collapsing: bottom row first, others cascade up. Reversed
    // direction keeps the "rolling under the header" feel symmetric.
    private func rowDelay(index: Int, total: Int, expanding: Bool) -> Double {
        let step = 0.06
        return expanding
            ? Double(index) * step
            : Double(total - 1 - index) * step
    }

    private func tripRowLink(for trip: Trip) -> some View {
        NavigationLink(value: TripDestination(trip: trip)) {
            TripRow(trip: trip)
                .padding(.horizontal, TKSpacing.md)
                .padding(.vertical, TKSpacing.sm)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                tripPendingDeletion = trip
            } label: {
                Label("Delete Trip", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func sectionHeaderRow(
        title: String,
        systemImage: String,
        collapseBinding: Binding<Bool>?
    ) -> some View {
        if let collapseBinding {
            Button {
                withAnimation(.smooth(duration: 0.45)) {
                    collapseBinding.wrappedValue.toggle()
                }
            } label: {
                HStack {
                    sectionHeader(title, systemImage: systemImage)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(TKTypography.metadataEmphasized)
                        .foregroundStyle(TKColors.textSecondary)
                        .rotationEffect(.degrees(collapseBinding.wrappedValue ? 0 : -90))
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
                .padding(.horizontal, TKSpacing.xs)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title) trips")
            .accessibilityValue(collapseBinding.wrappedValue ? "Expanded" : "Collapsed")
            .accessibilityHint("Double tap to \(collapseBinding.wrappedValue ? "collapse" : "expand")")
        } else {
            sectionHeader(title, systemImage: systemImage)
                .padding(.horizontal, TKSpacing.xs)
        }
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
            // Brand-colored leading "boarding-pass spine." Decorative cue
            // shared by every trip row, irrespective of status — status is
            // still carried by the badge text below. Hidden from VoiceOver.
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(TKColors.brand)
                .frame(width: 3)
                .frame(maxHeight: .infinity)
                .accessibilityHidden(true)

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
