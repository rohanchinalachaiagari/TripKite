import SwiftUI

// V2.8 adaptive shell. On regular-width devices (iPad in full screen and
// large iPad split-screen) we render a NavigationSplitView with a sidebar so
// the app feels intentional on a large canvas. On compact-width devices
// (every iPhone, plus iPad in narrow split-screen) we keep the existing
// RootTabView with its bottom tab bar.
//
// Both branches share the same dependency graph; this view just routes them
// into whichever shell the size class wants.
struct RootView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

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
        if horizontalSizeClass == .regular {
            RootSidebarView(
                tripRepository: tripRepository,
                itineraryRepository: itineraryRepository,
                notificationService: notificationService,
                documentRepository: documentRepository,
                documentStorage: documentStorage,
                settingsStore: settingsStore,
                dataManagement: dataManagement,
                searchService: searchService,
                locationActions: locationActions,
                appRouter: appRouter
            )
        } else {
            RootTabView(
                tripRepository: tripRepository,
                itineraryRepository: itineraryRepository,
                notificationService: notificationService,
                documentRepository: documentRepository,
                documentStorage: documentStorage,
                settingsStore: settingsStore,
                dataManagement: dataManagement,
                searchService: searchService,
                locationActions: locationActions,
                appRouter: appRouter
            )
        }
    }
}
