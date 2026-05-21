import XCTest
@testable import TripKite

final class LocalSearchServiceTests: XCTestCase {

    // MARK: - Empty / whitespace queries

    func testSearch_WithEmptyQuery_ReturnsEmptyResults() async throws {
        let fixture = await makeFixture()
        let results = try await fixture.service.search(SearchQuery(""))
        XCTAssertTrue(results.isEmpty)
        XCTAssertEqual(results.tripsById, [:])
    }

    func testSearch_WithWhitespaceOnlyQuery_ReturnsEmptyResults() async throws {
        let fixture = await makeFixture()
        let results = try await fixture.service.search(SearchQuery("   \n  "))
        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - Trip matches

    func testSearch_MatchesTripTitleCaseInsensitively() async throws {
        let fixture = await makeFixture()
        let results = try await fixture.service.search(SearchQuery("tokyo"))
        XCTAssertEqual(results.trips.map(\.id), [fixture.tokyo.id])
    }

    func testSearch_MatchesTripDestinationDiacriticInsensitively() async throws {
        let fixture = await makeFixture()
        // The trip's destination is "Paris, France". Searching for "francais"
        // wouldn't match — but "cafe" should match the Paris café itinerary
        // item below. Use the trip's notes field for the diacritic check.
        let results = try await fixture.service.search(SearchQuery("cafe"))
        XCTAssertTrue(results.items.contains(where: { $0.id == fixture.parisCafe.id }))
    }

    func testSearch_MatchesTripNotes() async throws {
        let fixture = await makeFixture()
        let results = try await fixture.service.search(SearchQuery("honeymoon"))
        XCTAssertEqual(results.trips.map(\.id), [fixture.paris.id])
    }

    // MARK: - Itinerary matches

    func testSearch_MatchesItineraryConfirmationNumber() async throws {
        let fixture = await makeFixture()
        let results = try await fixture.service.search(SearchQuery("ABC123"))
        XCTAssertEqual(results.items.map(\.id), [fixture.tokyoFlight.id])
    }

    func testSearch_MatchesItineraryTypeDisplayName() async throws {
        let fixture = await makeFixture()
        let results = try await fixture.service.search(SearchQuery("flight"))
        XCTAssertTrue(results.items.contains(where: { $0.id == fixture.tokyoFlight.id }))
    }

    func testSearch_MatchesItineraryAddress() async throws {
        let fixture = await makeFixture()
        let results = try await fixture.service.search(SearchQuery("rivoli"))
        XCTAssertEqual(results.items.map(\.id), [fixture.parisCafe.id])
    }

    // MARK: - Document matches

    func testSearch_MatchesDocumentFileName() async throws {
        let fixture = await makeFixture()
        let results = try await fixture.service.search(SearchQuery("boarding"))
        XCTAssertEqual(results.documents.map(\.id), [fixture.boardingPass.id])
    }

    func testSearch_MatchesDocumentFileType() async throws {
        let fixture = await makeFixture()
        let results = try await fixture.service.search(SearchQuery("pdf"))
        XCTAssertEqual(Set(results.documents.map(\.id)), [fixture.boardingPass.id])
    }

    // MARK: - Sorting & cross-type results

    func testSearch_ReturnsTripsSortedByStartDateAscending() async throws {
        let fixture = await makeFixture()
        // Query "trip" appears in both trips' notes.
        let results = try await fixture.service.search(SearchQuery("trip"))
        XCTAssertEqual(results.trips.map(\.id), [fixture.tokyo.id, fixture.paris.id])
    }

    func testSearch_ReturnsItemsSortedByStartDateAscending() async throws {
        let fixture = await makeFixture()
        // "hotel" matches both the Tokyo hotel and the Paris hotel (via title).
        let results = try await fixture.service.search(SearchQuery("hotel"))
        XCTAssertEqual(results.items.map(\.id), [fixture.tokyoHotel.id, fixture.parisHotel.id])
    }

    func testSearch_ReturnsDocumentsSortedByCreatedAtDescending() async throws {
        let fixture = await makeFixture()
        // Both documents have "Trip" in the filename — newer one comes first.
        let results = try await fixture.service.search(SearchQuery("trip"))
        XCTAssertEqual(results.documents.map(\.id), [fixture.parisItinerary.id, fixture.boardingPass.id])
    }

    func testSearch_PopulatesTripsByIdForAllFetchedTrips() async throws {
        let fixture = await makeFixture()
        let results = try await fixture.service.search(SearchQuery("tokyo"))
        XCTAssertEqual(Set(results.tripsById.keys), [fixture.tokyo.id, fixture.paris.id])
    }

    // MARK: - Errors

    func testSearch_PropagatesRepositoryError() async {
        let fixture = await makeFixture()
        struct Boom: Error {}
        await fixture.tripRepo.setFetchError(Boom())
        do {
            _ = try await fixture.service.search(SearchQuery("tokyo"))
            XCTFail("Expected error to propagate")
        } catch {
            // Expected.
        }
    }

    // MARK: - Fixture

    private struct Fixture {
        let service: LocalSearchService
        let tripRepo: MockTripRepository
        let tokyo: Trip
        let paris: Trip
        let tokyoFlight: ItineraryItem
        let tokyoHotel: ItineraryItem
        let parisHotel: ItineraryItem
        let parisCafe: ItineraryItem
        let boardingPass: TravelDocument
        let parisItinerary: TravelDocument
    }

    private func makeFixture() async -> Fixture {
        let cal = Calendar(identifier: .gregorian)
        let day = { (year: Int, month: Int, day: Int) in
            cal.date(from: DateComponents(year: year, month: month, day: day))!
        }

        let tokyo = Trip(
            title: "Tokyo Adventure",
            destination: "Tokyo, Japan",
            startDate: day(2026, 6, 1),
            endDate: day(2026, 6, 10),
            notes: "Big trip with family"
        )
        let paris = Trip(
            title: "Paris Getaway",
            destination: "Paris, France",
            startDate: day(2026, 9, 1),
            endDate: day(2026, 9, 8),
            notes: "Honeymoon trip"
        )

        let tokyoFlight = ItineraryItem(
            tripId: tokyo.id,
            title: "ANA NH 7",
            type: .flight,
            startDate: day(2026, 6, 1),
            confirmationNumber: "ABC123"
        )
        let tokyoHotel = ItineraryItem(
            tripId: tokyo.id,
            title: "Park Hyatt Hotel",
            type: .hotel,
            startDate: day(2026, 6, 1)
        )
        let parisHotel = ItineraryItem(
            tripId: paris.id,
            title: "Le Petit Hotel",
            type: .hotel,
            startDate: day(2026, 9, 1)
        )
        let parisCafe = ItineraryItem(
            tripId: paris.id,
            title: "Café de Flore",
            type: .restaurant,
            startDate: day(2026, 9, 2),
            address: "228 Rue de Rivoli"
        )

        let boardingPass = TravelDocument(
            tripId: tokyo.id,
            fileName: "Tokyo Trip Boarding Pass",
            localRelativePath: "Attachments/bp.pdf",
            fileType: "pdf",
            createdAt: day(2026, 5, 15)
        )
        let parisItinerary = TravelDocument(
            tripId: paris.id,
            fileName: "Paris Trip Itinerary",
            localRelativePath: "Attachments/itin.png",
            fileType: "png",
            createdAt: day(2026, 8, 15)
        )

        let tripRepo = MockTripRepository()
        let itineraryRepo = MockItineraryRepository()
        let documentRepo = MockDocumentRepository()
        await tripRepo.seed([tokyo, paris])
        await itineraryRepo.seedTripIds([tokyo.id, paris.id])
        await itineraryRepo.seed([tokyoFlight, tokyoHotel, parisHotel, parisCafe])
        await documentRepo.seedTripIds([tokyo.id, paris.id])
        await documentRepo.seed([boardingPass, parisItinerary])

        let service = LocalSearchService(
            tripRepository: tripRepo,
            itineraryRepository: itineraryRepo,
            documentRepository: documentRepo
        )

        return Fixture(
            service: service,
            tripRepo: tripRepo,
            tokyo: tokyo,
            paris: paris,
            tokyoFlight: tokyoFlight,
            tokyoHotel: tokyoHotel,
            parisHotel: parisHotel,
            parisCafe: parisCafe,
            boardingPass: boardingPass,
            parisItinerary: parisItinerary
        )
    }
}
