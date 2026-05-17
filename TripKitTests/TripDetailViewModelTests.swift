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
