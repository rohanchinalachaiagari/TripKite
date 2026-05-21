import Foundation
@testable import TripKite

final actor MockSearchService: SearchService {
    private(set) var queries: [SearchQuery] = []
    private var resultsByQuery: [String: SearchResults] = [:]
    private var defaultResults: SearchResults = .empty
    private var searchError: Error?

    func setResults(_ results: SearchResults, for query: String) {
        resultsByQuery[query] = results
    }

    func setDefaultResults(_ results: SearchResults) {
        defaultResults = results
    }

    func setSearchError(_ error: Error?) {
        searchError = error
    }

    func search(_ query: SearchQuery) async throws -> SearchResults {
        queries.append(query)
        if let searchError { throw searchError }
        return resultsByQuery[query.normalized] ?? defaultResults
    }
}
