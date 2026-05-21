import Foundation
import Combine

@MainActor
final class SearchViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case searching
        case empty(query: String)
        case results(SearchResults)
        case error(String)
    }

    @Published var query: String = ""
    @Published private(set) var state: State = .idle

    private let searchService: SearchService
    private let router: AppRouter
    private let documentStorage: DocumentStorageService
    private let debounce: Duration

    // Most-recent-wins: each onQueryChange cancels the previous in-flight task.
    private var activeSearch: Task<Void, Never>?

    init(
        searchService: SearchService,
        router: AppRouter,
        documentStorage: DocumentStorageService,
        debounce: Duration = .milliseconds(150)
    ) {
        self.searchService = searchService
        self.router = router
        self.documentStorage = documentStorage
        self.debounce = debounce
    }

    func onQueryChange() {
        activeSearch?.cancel()

        let raw = query
        let searchQuery = SearchQuery(raw)
        if searchQuery.isEmpty {
            state = .idle
            return
        }

        state = .searching
        let service = searchService
        let debounce = debounce
        activeSearch = Task { [weak self] in
            try? await Task.sleep(for: debounce)
            if Task.isCancelled { return }

            do {
                let results = try await service.search(searchQuery)
                if Task.isCancelled { return }
                await MainActor.run {
                    guard let self else { return }
                    // Guard against a late completion of a stale query.
                    guard self.query == raw else { return }
                    if results.isEmpty {
                        self.state = .empty(query: searchQuery.normalized)
                    } else {
                        self.state = .results(results)
                    }
                }
            } catch {
                if Task.isCancelled { return }
                await MainActor.run {
                    guard let self else { return }
                    guard self.query == raw else { return }
                    self.state = .error(error.localizedDescription)
                }
            }
        }
    }

    func clear() {
        activeSearch?.cancel()
        query = ""
        state = .idle
    }

    func selectTrip(_ trip: Trip) {
        router.pendingTripDetail = PendingTripRoute(tripId: trip.id, itemId: nil)
    }

    func selectItem(_ item: ItineraryItem) {
        router.pendingTripDetail = PendingTripRoute(tripId: item.tripId, itemId: item.id)
    }

    func absoluteURL(for document: TravelDocument) -> URL? {
        try? documentStorage.absoluteURL(for: document)
    }
}
