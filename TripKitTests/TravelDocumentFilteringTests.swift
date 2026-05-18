import XCTest
@testable import TripKit

final class TravelDocumentFilteringTests: XCTestCase {

    func testAttached_ReturnsOnlyMatchingItem() {
        let tripId = UUID()
        let itemA = UUID()
        let itemB = UUID()
        let match = makeDoc(tripId: tripId, itemId: itemA)
        let otherItem = makeDoc(tripId: tripId, itemId: itemB)
        let tripLevel = makeDoc(tripId: tripId, itemId: nil)

        let result = [otherItem, match, tripLevel].attached(toItemId: itemA)

        XCTAssertEqual(result.map(\.id), [match.id])
    }

    func testAttached_ExcludesDocumentsForOtherItems() {
        let tripId = UUID()
        let itemA = UUID()
        let itemB = UUID()
        let docs = [
            makeDoc(tripId: tripId, itemId: itemB),
            makeDoc(tripId: tripId, itemId: itemB),
        ]

        XCTAssertTrue(docs.attached(toItemId: itemA).isEmpty)
    }

    func testAttached_ExcludesTripLevelDocuments() {
        let tripId = UUID()
        let itemA = UUID()
        let docs = [
            makeDoc(tripId: tripId, itemId: nil),
            makeDoc(tripId: tripId, itemId: nil),
        ]

        XCTAssertTrue(docs.attached(toItemId: itemA).isEmpty)
    }

    func testAttached_EmptyInputReturnsEmpty() {
        let result: [TravelDocument] = [].attached(toItemId: UUID())
        XCTAssertTrue(result.isEmpty)
    }

    func testAttached_PreservesInputOrder() {
        let tripId = UUID()
        let itemA = UUID()
        let first = makeDoc(tripId: tripId, itemId: itemA, name: "First")
        let middle = makeDoc(tripId: tripId, itemId: UUID(), name: "Middle")
        let last = makeDoc(tripId: tripId, itemId: itemA, name: "Last")

        let result = [first, middle, last].attached(toItemId: itemA)

        XCTAssertEqual(result.map(\.fileName), ["First", "Last"])
    }

    // MARK: - Helpers

    private func makeDoc(
        tripId: UUID,
        itemId: UUID?,
        name: String = "Doc"
    ) -> TravelDocument {
        TravelDocument(
            tripId: tripId,
            itineraryItemId: itemId,
            fileName: name,
            localRelativePath: "Attachments/\(UUID().uuidString).pdf",
            fileType: "pdf"
        )
    }
}
