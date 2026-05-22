import XCTest
@testable import TripKite

@MainActor
final class TripDetailViewModelTests: XCTestCase {

    func testLoad_PopulatesItemsForTrip() async {
        let trip = makeTrip()
        let mine = ItineraryItem(
            tripId: trip.id,
            title: "Mine",
            type: .activity,
            startDate: Date()
        )
        let theirs = ItineraryItem(
            tripId: UUID(),
            title: "Theirs",
            type: .activity,
            startDate: Date()
        )
        let itineraryMock = MockItineraryRepository()
        await itineraryMock.seed([mine, theirs])
        let tripMock = MockTripRepository()
        await tripMock.seed([trip])

        let vm = TripDetailViewModel(
            trip: trip,
            itineraryRepository: itineraryMock,
            tripRepository: tripMock,
            notificationService: MockNotificationSchedulingService(),
            locationActions: MockLocationActionService()
        )
        await vm.load()

        XCTAssertEqual(vm.items.map(\.title), ["Mine"])
        XCTAssertNil(vm.errorMessage)
    }

    func testLoad_OnError_SetsErrorMessage() async {
        let trip = makeTrip()
        let itineraryMock = MockItineraryRepository()
        struct BoomError: LocalizedError { var errorDescription: String? { "Boom" } }
        await itineraryMock.setFetchError(BoomError())
        let tripMock = MockTripRepository()

        let vm = TripDetailViewModel(
            trip: trip,
            itineraryRepository: itineraryMock,
            tripRepository: tripMock,
            notificationService: MockNotificationSchedulingService(),
            locationActions: MockLocationActionService()
        )
        await vm.load()

        XCTAssertTrue(vm.items.isEmpty)
        XCTAssertEqual(vm.errorMessage, "Boom")
    }

    func testDeleteItem_RemovesFromListAndRepository() async {
        let trip = makeTrip()
        let item = ItineraryItem(
            tripId: trip.id,
            title: "Delete me",
            type: .activity,
            startDate: Date()
        )
        let itineraryMock = MockItineraryRepository()
        await itineraryMock.seed([item])
        let tripMock = MockTripRepository()

        let vm = TripDetailViewModel(
            trip: trip,
            itineraryRepository: itineraryMock,
            tripRepository: tripMock,
            notificationService: MockNotificationSchedulingService(),
            locationActions: MockLocationActionService()
        )
        await vm.load()
        XCTAssertEqual(vm.items.count, 1)

        await vm.deleteItem(item)

        XCTAssertTrue(vm.items.isEmpty)
        let stored = await itineraryMock.storage[item.id]
        XCTAssertNil(stored)
    }

    func testDeleteItem_OnError_SetsErrorMessageAndKeepsItem() async {
        let trip = makeTrip()
        let item = ItineraryItem(
            tripId: trip.id,
            title: "Stuck",
            type: .activity,
            startDate: Date()
        )
        let itineraryMock = MockItineraryRepository()
        await itineraryMock.seed([item])
        struct BoomError: LocalizedError { var errorDescription: String? { "Nope" } }
        await itineraryMock.setDeleteError(BoomError())
        let tripMock = MockTripRepository()

        let vm = TripDetailViewModel(
            trip: trip,
            itineraryRepository: itineraryMock,
            tripRepository: tripMock,
            notificationService: MockNotificationSchedulingService(),
            locationActions: MockLocationActionService()
        )
        await vm.load()
        await vm.deleteItem(item)

        XCTAssertEqual(vm.items.map(\.id), [item.id])
        XCTAssertEqual(vm.errorMessage, "Nope")
    }

    func testFocus_UsesInjectedNowAndLoadedItems() async {
        let trip = makeTrip()
        let now = Date()
        let active = ItineraryItem(
            tripId: trip.id,
            title: "Tour",
            type: .activity,
            startDate: now.addingTimeInterval(-30 * 60),
            endDate: now.addingTimeInterval(60 * 60)
        )
        let upcoming = ItineraryItem(
            tripId: trip.id,
            title: "Dinner",
            type: .restaurant,
            startDate: now.addingTimeInterval(3 * 3600)
        )
        let itineraryMock = MockItineraryRepository()
        await itineraryMock.seed([active, upcoming])
        let tripMock = MockTripRepository()

        let vm = TripDetailViewModel(
            trip: trip,
            itineraryRepository: itineraryMock,
            tripRepository: tripMock,
            notificationService: MockNotificationSchedulingService(),
            locationActions: MockLocationActionService(),
            now: { now }
        )
        await vm.load()

        XCTAssertEqual(vm.focus, .happeningNow(active))
    }

    func testFocus_WhenItemsEmpty_IsNil() {
        let trip = makeTrip()
        let vm = TripDetailViewModel(
            trip: trip,
            itineraryRepository: MockItineraryRepository(),
            tripRepository: MockTripRepository(),
            notificationService: MockNotificationSchedulingService(),
            locationActions: MockLocationActionService(),
            now: { Date() }
        )
        XCTAssertNil(vm.focus)
    }

    func testRefreshTrip_UpdatesTripFromRepository() async {
        let original = makeTrip()
        var renamed = original
        renamed.title = "Renamed"
        let itineraryMock = MockItineraryRepository()
        let tripMock = MockTripRepository()
        await tripMock.seed([renamed])

        let vm = TripDetailViewModel(
            trip: original,
            itineraryRepository: itineraryMock,
            tripRepository: tripMock,
            notificationService: MockNotificationSchedulingService(),
            locationActions: MockLocationActionService()
        )
        await vm.refreshTrip()

        XCTAssertEqual(vm.trip.title, "Renamed")
    }

    func testDeleteItem_CancelsReminderBeforeDeletion() async {
        let trip = makeTrip()
        let item = ItineraryItem(
            tripId: trip.id,
            title: "Reminded",
            type: .activity,
            startDate: Date(),
            reminderOffset: 600
        )
        let itineraryMock = MockItineraryRepository()
        await itineraryMock.seed([item])
        let notifications = MockNotificationSchedulingService()

        let vm = TripDetailViewModel(
            trip: trip,
            itineraryRepository: itineraryMock,
            tripRepository: MockTripRepository(),
            notificationService: notifications,
            locationActions: MockLocationActionService()
        )
        await vm.load()
        await vm.deleteItem(item)

        let cancellations = await notifications.itemCancellations
        XCTAssertEqual(cancellations, [item.id])
        let stored = await itineraryMock.storage[item.id]
        XCTAssertNil(stored)
    }

    // MARK: - Location quick-actions

    func testOpenInMaps_DelegatesToServiceWithItemLocationFields() {
        let trip = makeTrip()
        let item = ItineraryItem(
            tripId: trip.id,
            title: "Hotel",
            type: .hotel,
            startDate: Date(),
            locationName: "Park Hyatt",
            address: "3-7-1 Nishi Shinjuku"
        )
        let actions = MockLocationActionService()
        let vm = makeViewModel(trip: trip, locationActions: actions)

        vm.openInMaps(for: item)

        XCTAssertEqual(
            actions.openInMapsCalls,
            [MockLocationActionService.OpenInMapsCall(name: "Park Hyatt", address: "3-7-1 Nishi Shinjuku")]
        )
        XCTAssertTrue(actions.copyCalls.isEmpty)
    }

    func testCopyAddress_DelegatesToService() {
        let trip = makeTrip()
        let item = ItineraryItem(
            tripId: trip.id,
            title: "Hotel",
            type: .hotel,
            startDate: Date(),
            locationName: "Park Hyatt",
            address: "3-7-1 Nishi Shinjuku"
        )
        let actions = MockLocationActionService()
        let vm = makeViewModel(trip: trip, locationActions: actions)

        vm.copyAddress(of: item)

        XCTAssertEqual(actions.copyCalls, ["3-7-1 Nishi Shinjuku"])
        XCTAssertTrue(actions.openInMapsCalls.isEmpty)
    }

    func testCopyLocationName_DelegatesToService() {
        let trip = makeTrip()
        let item = ItineraryItem(
            tripId: trip.id,
            title: "Hotel",
            type: .hotel,
            startDate: Date(),
            locationName: "Park Hyatt",
            address: ""
        )
        let actions = MockLocationActionService()
        let vm = makeViewModel(trip: trip, locationActions: actions)

        vm.copyLocationName(of: item)

        XCTAssertEqual(actions.copyCalls, ["Park Hyatt"])
    }

    func testAvailableLocationActions_ReflectsItemFields() {
        let trip = makeTrip()
        let both = ItineraryItem(
            tripId: trip.id,
            title: "Both",
            type: .activity,
            startDate: Date(),
            locationName: "Café",
            address: "1 Apple Park Way"
        )
        let addressOnly = ItineraryItem(
            tripId: trip.id,
            title: "Addr",
            type: .activity,
            startDate: Date(),
            locationName: "",
            address: "1 Apple Park Way"
        )
        let nameOnly = ItineraryItem(
            tripId: trip.id,
            title: "Name",
            type: .activity,
            startDate: Date(),
            locationName: "Café",
            address: ""
        )
        let neither = ItineraryItem(
            tripId: trip.id,
            title: "Empty",
            type: .activity,
            startDate: Date()
        )
        let vm = makeViewModel(trip: trip, locationActions: MockLocationActionService())

        XCTAssertEqual(vm.availableLocationActions(for: both), [.openInMaps, .copyAddress, .copyLocationName])
        XCTAssertEqual(vm.availableLocationActions(for: addressOnly), [.openInMaps, .copyAddress])
        XCTAssertEqual(vm.availableLocationActions(for: nameOnly), [.openInMaps, .copyLocationName])
        XCTAssertTrue(vm.availableLocationActions(for: neither).isEmpty)
    }

    // MARK: - Helpers

    // No default value for `locationActions` because Swift's strict
    // concurrency treats default-value expressions as a nonisolated context,
    // and `MockLocationActionService.init` is MainActor-isolated. Callers
    // construct the mock from inside their (MainActor) test body.
    private func makeViewModel(
        trip: Trip,
        locationActions: MockLocationActionService
    ) -> TripDetailViewModel {
        TripDetailViewModel(
            trip: trip,
            itineraryRepository: MockItineraryRepository(),
            tripRepository: MockTripRepository(),
            notificationService: MockNotificationSchedulingService(),
            locationActions: locationActions
        )
    }

    private func makeTrip() -> Trip {
        Trip(
            title: "Tokyo",
            destination: "Tokyo",
            startDate: Date(),
            endDate: Date().addingTimeInterval(86_400)
        )
    }
}
