import SwiftUI
import UserNotifications

@main
struct TripKitApp: App {
    private let tripRepository: TripRepository
    private let itineraryRepository: ItineraryRepository
    private let notificationService: NotificationSchedulingService
    private let documentRepository: DocumentRepository
    private let documentStorage: DocumentStorageService
    private let notificationHandler: NotificationResponseHandler

    @StateObject private var appRouter: AppRouter

    init() {
        let stack = CoreDataStack()
        self.tripRepository = CoreDataTripRepository(stack: stack)
        self.itineraryRepository = CoreDataItineraryRepository(stack: stack)
        self.notificationService = UserNotificationSchedulingService()
        self.documentRepository = CoreDataDocumentRepository(stack: stack)
        self.documentStorage = FileManagerDocumentStorageService()

        let router = AppRouter()
        let handler = NotificationResponseHandler(router: router)
        UNUserNotificationCenter.current().delegate = handler
        self.notificationHandler = handler
        _appRouter = StateObject(wrappedValue: router)
    }

    var body: some Scene {
        WindowGroup {
            TripListView(
                tripRepository: tripRepository,
                itineraryRepository: itineraryRepository,
                notificationService: notificationService,
                documentRepository: documentRepository,
                documentStorage: documentStorage,
                appRouter: appRouter
            )
        }
    }
}
