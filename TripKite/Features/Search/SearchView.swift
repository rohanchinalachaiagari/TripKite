import SwiftUI

struct SearchView: View {
    @StateObject private var viewModel: SearchViewModel
    @State private var previewURL: URL?

    init(
        searchService: SearchService,
        router: AppRouter,
        documentStorage: DocumentStorageService
    ) {
        _viewModel = StateObject(
            wrappedValue: SearchViewModel(
                searchService: searchService,
                router: router,
                documentStorage: documentStorage
            )
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                TKBackground()
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Search")
            .searchable(
                text: $viewModel.query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search trips, items, documents"
            )
            .onChange(of: viewModel.query) { _, _ in
                viewModel.onQueryChange()
            }
            .quickLookSheet(url: $previewURL)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            TKEmptyStateView(
                systemImage: "magnifyingglass",
                title: "Search your trips",
                message: "Find a flight by confirmation number, a hotel by city, or a screenshot by name. Search covers trips, itinerary items, and documents."
            )
        case .searching:
            ProgressView()
        case .empty(let query):
            TKEmptyStateView(
                systemImage: "magnifyingglass",
                title: "No matches",
                message: "Nothing found for \u{201C}\(query)\u{201D}."
            )
        case .error(let message):
            TKEmptyStateView(
                systemImage: "exclamationmark.triangle",
                title: "Something went wrong",
                message: message
            )
        case .results(let results):
            resultsList(results)
        }
    }

    private func resultsList(_ results: SearchResults) -> some View {
        List {
            if !results.trips.isEmpty {
                Section {
                    ForEach(results.trips) { trip in
                        TripResultRow(trip: trip) {
                            viewModel.selectTrip(trip)
                        }
                    }
                } header: {
                    sectionHeader("Trips", systemImage: "suitcase.fill")
                }
            }

            if !results.items.isEmpty {
                Section {
                    ForEach(results.items) { item in
                        ItineraryResultRow(
                            item: item,
                            parentTrip: results.tripsById[item.tripId]
                        ) {
                            viewModel.selectItem(item)
                        }
                    }
                } header: {
                    sectionHeader("Itinerary Items", systemImage: "calendar")
                }
            }

            if !results.documents.isEmpty {
                Section {
                    ForEach(results.documents) { document in
                        let parentTitle = results.tripsById[document.tripId]?.title
                        DocumentRowView(
                            document: document,
                            subtitle: SearchDocumentSubtitle.make(
                                for: document,
                                parentTripTitle: parentTitle
                            ),
                            onTap: { previewURL = viewModel.absoluteURL(for: document) }
                        )
                    }
                } header: {
                    sectionHeader("Documents", systemImage: "doc.on.doc.fill")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(TKTypography.sectionHeader)
            .foregroundStyle(TKColors.textSecondary)
            .textCase(nil)
    }
}

#if DEBUG
#Preview("Seeded") {
    let stack = CoreDataStack.previewSeeded()
    SearchView(
        searchService: LocalSearchService(
            tripRepository: CoreDataTripRepository(stack: stack),
            itineraryRepository: CoreDataItineraryRepository(stack: stack),
            documentRepository: CoreDataDocumentRepository(stack: stack)
        ),
        router: AppRouter(),
        documentStorage: FileManagerDocumentStorageService()
    )
}

#Preview("Empty") {
    let stack = CoreDataStack(inMemory: true)
    SearchView(
        searchService: LocalSearchService(
            tripRepository: CoreDataTripRepository(stack: stack),
            itineraryRepository: CoreDataItineraryRepository(stack: stack),
            documentRepository: CoreDataDocumentRepository(stack: stack)
        ),
        router: AppRouter(),
        documentStorage: FileManagerDocumentStorageService()
    )
}
#endif
