import SwiftUI

// V2.1 app shell. Hosts the four long-term tabs (Trips, Search, Documents,
// Settings) and routes notification deep-links into the Trips tab so the
// existing `TripListView.handlePendingRoute` can consume them unchanged.
//
// RootTabView does not own navigation state for any tab. Each tab body owns
// its own NavigationStack — the Trips tab via `TripListView`, the placeholders
// via their own NavigationStack so their large titles render consistently.
//
// `pendingTripDetail` is observed here only to force the Trips tab into view
// when a notification arrives. RootTabView never clears the route; clearing
// stays the responsibility of `TripListView.handlePendingRoute` so the V1
// routing flow is unchanged.
struct RootTabView: View {
    @ObservedObject private var appRouter: AppRouter
    private let tripRepository: TripRepository
    private let itineraryRepository: ItineraryRepository
    private let notificationService: NotificationSchedulingService
    private let documentRepository: DocumentRepository
    private let documentStorage: DocumentStorageService
    private let settingsStore: SettingsStore
    private let dataManagement: DataManagementService

    @State private var selectedTab: Tab = .trips

    private enum Tab: Hashable {
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
        appRouter: AppRouter
    ) {
        self.tripRepository = tripRepository
        self.itineraryRepository = itineraryRepository
        self.notificationService = notificationService
        self.documentRepository = documentRepository
        self.documentStorage = documentStorage
        self.settingsStore = settingsStore
        self.dataManagement = dataManagement
        self.appRouter = appRouter
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            TripListView(
                tripRepository: tripRepository,
                itineraryRepository: itineraryRepository,
                notificationService: notificationService,
                documentRepository: documentRepository,
                documentStorage: documentStorage,
                settingsStore: settingsStore,
                appRouter: appRouter
            )
            .tabItem {
                Label("Trips", systemImage: "suitcase.fill")
            }
            .tag(Tab.trips)

            SearchPlaceholderView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(Tab.search)

            DocumentVaultView(
                documentRepository: documentRepository,
                tripRepository: tripRepository,
                itineraryRepository: itineraryRepository,
                documentStorage: documentStorage
            )
            .tabItem {
                Label("Documents", systemImage: "doc.on.doc.fill")
            }
            .tag(Tab.documents)

            SettingsView(
                settingsStore: settingsStore,
                dataManagement: dataManagement,
                notificationService: notificationService
            )
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
            .tag(Tab.settings)
        }
        .onChange(of: appRouter.pendingTripDetail) { _, newRoute in
            // Force the Trips tab into view when a notification deep-link
            // arrives. Do not touch the route — TripListView consumes and
            // clears it.
            if newRoute != nil {
                selectedTab = .trips
            }
        }
    }
}

#if DEBUG
private func previewDependencies(stack: CoreDataStack) -> (
    SettingsStore,
    DataManagementService,
    NotificationSchedulingService
) {
    let settings = UserDefaultsSettingsStore(defaults: UserDefaults(suiteName: "TripKite-Preview")!)
    let notifications = UserNotificationSchedulingService()
    let data = LocalDataManagementService(
        tripRepository: CoreDataTripRepository(stack: stack),
        documentRepository: CoreDataDocumentRepository(stack: stack),
        documentStorage: FileManagerDocumentStorageService(),
        notificationService: notifications,
        settingsStore: settings
    )
    return (settings, data, notifications)
}

#Preview("Seeded") {
    let stack = CoreDataStack.previewSeeded()
    let (settings, data, notifications) = previewDependencies(stack: stack)
    RootTabView(
        tripRepository: CoreDataTripRepository(stack: stack),
        itineraryRepository: CoreDataItineraryRepository(stack: stack),
        notificationService: notifications,
        documentRepository: CoreDataDocumentRepository(stack: stack),
        documentStorage: FileManagerDocumentStorageService(),
        settingsStore: settings,
        dataManagement: data,
        appRouter: AppRouter()
    )
}

#Preview("Empty") {
    let stack = CoreDataStack(inMemory: true)
    let (settings, data, notifications) = previewDependencies(stack: stack)
    RootTabView(
        tripRepository: CoreDataTripRepository(stack: stack),
        itineraryRepository: CoreDataItineraryRepository(stack: stack),
        notificationService: notifications,
        documentRepository: CoreDataDocumentRepository(stack: stack),
        documentStorage: FileManagerDocumentStorageService(),
        settingsStore: settings,
        dataManagement: data,
        appRouter: AppRouter()
    )
}
#endif
