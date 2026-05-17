import XCTest
@testable import TripKit

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
            tripRepository: tripMock
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
            tripRepository: tripMock
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
            tripRepository: tripMock
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
            tripRepository: tripMock
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
            tripRepository: tripMock
        )
        await vm.refreshTrip()

        XCTAssertEqual(vm.trip.title, "Renamed")
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
