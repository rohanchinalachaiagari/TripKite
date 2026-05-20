import SwiftUI
import UserNotifications

@main
struct TripKiteApp: App {
    private let tripRepository: TripRepository
    private let itineraryRepository: ItineraryRepository
    private let notificationService: NotificationSchedulingService
    private let documentRepository: DocumentRepository
    private let documentStorage: DocumentStorageService
    private let settingsStore: SettingsStore
    private let dataManagement: DataManagementService
    private let notificationHandler: NotificationResponseHandler

    @StateObject private var appRouter: AppRouter

    init() {
        let stack = CoreDataStack()
        let tripRepo = CoreDataTripRepository(stack: stack)
        let itineraryRepo = CoreDataItineraryRepository(stack: stack)
        let documentRepo = CoreDataDocumentRepository(stack: stack)
        let docStorage = FileManagerDocumentStorageService()
        let notifications = UserNotificationSchedulingService()
        let settings = UserDefaultsSettingsStore()

        self.tripRepository = tripRepo
        self.itineraryRepository = itineraryRepo
        self.notificationService = notifications
        self.documentRepository = documentRepo
        self.documentStorage = docStorage
        self.settingsStore = settings
        self.dataManagement = LocalDataManagementService(
            tripRepository: tripRepo,
            documentRepository: documentRepo,
            documentStorage: docStorage,
            notificationService: notifications,
            settingsStore: settings
        )

        let router = AppRouter()
        let handler = NotificationResponseHandler(router: router)
        UNUserNotificationCenter.current().delegate = handler
        self.notificationHandler = handler
        _appRouter = StateObject(wrappedValue: router)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView(
                tripRepository: tripRepository,
                itineraryRepository: itineraryRepository,
                notificationService: notificationService,
                documentRepository: documentRepository,
                documentStorage: documentStorage,
                settingsStore: settingsStore,
                dataManagement: dataManagement,
                appRouter: appRouter
            )
        }
    }
}
