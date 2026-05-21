import XCTest
@testable import TripKite

@MainActor
final class SearchViewModelTests: XCTestCase {

    func testInitialState_IsIdle() {
        let vm = makeViewModel().vm
        XCTAssertEqual(vm.state, .idle)
        XCTAssertEqual(vm.query, "")
    }

    func testQueryChange_ToEmptyString_StaysIdle() async {
        let context = makeViewModel()
        context.vm.query = "   "
        context.vm.onQueryChange()
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(context.vm.state, .idle)
    }

    func testQueryChange_TransitionsToResults_WhenServiceReturnsResults() async {
        let trip = makeTrip(title: "Tokyo")
        let context = makeViewModel()
        let results = SearchResults(
            trips: [trip],
            items: [],
            documents: [],
            tripsById: [trip.id: trip]
        )
        await context.service.setResults(results, for: "tokyo")

        context.vm.query = "tokyo"
        context.vm.onQueryChange()
        await waitForResultState(context.vm)

        guard case .results(let actual) = context.vm.state else {
            XCTFail("Expected .results, got \(context.vm.state)")
            return
        }
        XCTAssertEqual(actual.trips.map(\.id), [trip.id])
    }

    func testQueryChange_TransitionsToEmpty_WhenServiceReturnsNoResults() async {
        let context = makeViewModel()
        await context.service.setDefaultResults(.empty)

        context.vm.query = "zzz"
        context.vm.onQueryChange()
        await waitForNonSearchingState(context.vm)

        XCTAssertEqual(context.vm.state, .empty(query: "zzz"))
    }

    func testQueryChange_PropagatesError_AsErrorState() async {
        let context = makeViewModel()
        struct Boom: LocalizedError {
            var errorDescription: String? { "boom" }
        }
        await context.service.setSearchError(Boom())

        context.vm.query = "anything"
        context.vm.onQueryChange()
        await waitForNonSearchingState(context.vm)

        XCTAssertEqual(context.vm.state, .error("boom"))
    }

    func testClear_ResetsQueryAndState() async {
        let trip = makeTrip(title: "Tokyo")
        let context = makeViewModel()
        let results = SearchResults(trips: [trip], items: [], documents: [], tripsById: [trip.id: trip])
        await context.service.setResults(results, for: "tokyo")

        context.vm.query = "tokyo"
        context.vm.onQueryChange()
        await waitForResultState(context.vm)

        context.vm.clear()
        XCTAssertEqual(context.vm.query, "")
        XCTAssertEqual(context.vm.state, .idle)
    }

    func testRapidQueryChanges_OnlyLatestResultIsApplied() async {
        let oldTrip = makeTrip(title: "Old")
        let newTrip = makeTrip(title: "New")
        let context = makeViewModel(debounce: .milliseconds(10))

        await context.service.setResults(
            SearchResults(trips: [oldTrip], items: [], documents: [], tripsById: [oldTrip.id: oldTrip]),
            for: "old"
        )
        await context.service.setResults(
            SearchResults(trips: [newTrip], items: [], documents: [], tripsById: [newTrip.id: newTrip]),
            for: "new"
        )

        context.vm.query = "old"
        context.vm.onQueryChange()
        context.vm.query = "new"
        context.vm.onQueryChange()

        await waitForResultState(context.vm)
        guard case .results(let actual) = context.vm.state else {
            XCTFail("Expected .results")
            return
        }
        XCTAssertEqual(actual.trips.map(\.id), [newTrip.id])
    }

    func testSelectTrip_SetsRouterPendingTripDetail_WithNilItemId() {
        let context = makeViewModel()
        let trip = makeTrip(title: "Tokyo")
        context.vm.selectTrip(trip)
        XCTAssertEqual(
            context.router.pendingTripDetail,
            PendingTripRoute(tripId: trip.id, itemId: nil)
        )
    }

    func testSelectItem_SetsRouterPendingTripDetail_WithItemId() {
        let context = makeViewModel()
        let trip = makeTrip(title: "Tokyo")
        let item = ItineraryItem(
            tripId: trip.id,
            title: "Flight",
            type: .flight,
            startDate: Date()
        )
        context.vm.selectItem(item)
        XCTAssertEqual(
            context.router.pendingTripDetail,
            PendingTripRoute(tripId: trip.id, itemId: item.id)
        )
    }

    func testAbsoluteURL_DelegatesToStorageService() async {
        let context = makeViewModel()
        let trip = makeTrip(title: "Tokyo")
        let document = TravelDocument(
            tripId: trip.id,
            fileName: "Boarding Pass",
            localRelativePath: "Attachments/bp.pdf",
            fileType: "pdf"
        )
        let url = context.vm.absoluteURL(for: document)
        XCTAssertEqual(url?.path, "/mock/Attachments/bp.pdf")
    }

    // MARK: - Helpers

    private struct Context {
        let vm: SearchViewModel
        let service: MockSearchService
        let router: AppRouter
        let storage: MockDocumentStorageService
    }

    private func makeViewModel(debounce: Duration = .milliseconds(10)) -> Context {
        let service = MockSearchService()
        let router = AppRouter()
        let storage = MockDocumentStorageService()
        let vm = SearchViewModel(
            searchService: service,
            router: router,
            documentStorage: storage,
            debounce: debounce
        )
        return Context(vm: vm, service: service, router: router, storage: storage)
    }

    private func makeTrip(title: String) -> Trip {
        Trip(
            title: title,
            destination: "Somewhere",
            startDate: Date(),
            endDate: Date().addingTimeInterval(86_400)
        )
    }

    // Polls the view model until it leaves `.searching`, with a small ceiling
    // so a stuck state surfaces as a test failure instead of a hang.
    private func waitForNonSearchingState(_ vm: SearchViewModel) async {
        for _ in 0..<100 {
            if vm.state != .searching { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    private func waitForResultState(_ vm: SearchViewModel) async {
        for _ in 0..<100 {
            if case .results = vm.state { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}
