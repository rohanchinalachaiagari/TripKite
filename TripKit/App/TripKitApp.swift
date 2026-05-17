import SwiftUI
import UserNotifications

@main
struct TripKitApp: App {
    private let tripRepository: TripRepository
    private let itineraryRepository: ItineraryRepository
    private let notificationService: NotificationSchedulingService
    private let notificationHandler: NotificationResponseHandler

    @StateObject private var appRouter: AppRouter

    init() {
        let stack = CoreDataStack()
        self.tripRepository = CoreDataTripRepository(stack: stack)
        self.itineraryRepository = CoreDataItineraryRepository(stack: stack)
        self.notificationService = UserNotificationSchedulingService()

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
                appRouter: appRouter
            )
        }
    }
}
