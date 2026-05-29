import SwiftUI

// iPad-only app shell. NavigationSplitView with a sidebar listing the four
// long-term sections (Trips, Search, Documents, Settings) and the matching
// content in the detail column. Notification taps and search-result taps
// still flip the section to Trips via the shared AppRouter channel — same
// behavior as the iPhone TabView.
struct RootSidebarView: View {
    @ObservedObject private var appRouter: AppRouter
    private let tripRepository: TripRepository
    private let itineraryRepository: ItineraryRepository
    private let notificationService: NotificationSchedulingService
    private let documentRepository: DocumentRepository
    private let documentStorage: DocumentStorageService
    private let settingsStore: SettingsStore
    private let dataManagement: DataManagementService
    private let searchService: SearchService
    private let locationActions: LocationActionService

    @State private var selection: Section? = .trips
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    private enum Section: Hashable {
        case trips
        case search
        case documents
        case settings
    }

    init(
        tripRepository: TripRepository,
        itineraryRepository: ItineraryRepository,
        notificationService: NotificationSchedulingService,
        documentRepository: DocumentRepository,
        documentStorage: DocumentStorageService,
        settingsStore: SettingsStore,
        dataManagement: DataManagementService,
        searchService: SearchService,
        locationActions: LocationActionService,
        appRouter: AppRouter
    ) {
        self.tripRepository = tripRepository
        self.itineraryRepository = itineraryRepository
        self.notificationService = notificationService
        self.documentRepository = documentRepository
        self.documentStorage = documentStorage
        self.settingsStore = settingsStore
        self.dataManagement = dataManagement
        self.searchService = searchService
        self.locationActions = locationActions
        self.appRouter = appRouter
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: appRouter.pendingTripDetail) { _, newRoute in
            // Mirror the iPhone routing: a non-nil deep link forces the Trips
            // section into the detail column. TripListView consumes and
            // clears the route via its own onChange handler.
            if newRoute != nil {
                selection = .trips
            }
        }
    }

    private var sidebar: some View {
        List(selection: $selection) {
            NavigationLink(value: Section.trips) {
                Label("Trips", systemImage: "suitcase.fill")
            }
            NavigationLink(value: Section.search) {
                Label("Search", systemImage: "magnifyingglass")
            }
            NavigationLink(value: Section.documents) {
                Label("Documents", systemImage: "doc.on.doc.fill")
            }
            NavigationLink(value: Section.settings) {
                Label("Settings", systemImage: "gearshape.fill")
            }
        }
        .navigationTitle("TripKite")
    }

    @ViewBuilder
    private var detail: some View {
        switch selection ?? .trips {
        case .trips:
            TripListView(
                tripRepository: tripRepository,
                itineraryRepository: itineraryRepository,
                notificationService: notificationService,
                documentRepository: documentRepository,
                documentStorage: documentStorage,
                settingsStore: settingsStore,
                locationActions: locationActions,
                appRouter: appRouter
            )
        case .search:
            SearchView(
                searchService: searchService,
                router: appRouter,
                documentStorage: documentStorage
            )
        case .documents:
            DocumentVaultView(
                documentRepository: documentRepository,
                tripRepository: tripRepository,
                itineraryRepository: itineraryRepository,
                documentStorage: documentStorage
            )
        case .settings:
            SettingsView(
                settingsStore: settingsStore,
                dataManagement: dataManagement,
                notificationService: notificationService
            )
        }
    }
}
