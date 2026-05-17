import XCTest
@testable import TripKit

@MainActor
final class TripEditorViewModelTests: XCTestCase {

    func testSave_CreateMode_CallsCreateOnRepository() async {
        let mock = MockTripRepository()
        let viewModel = TripEditorViewModel(mode: .create, repository: mock)
        viewModel.title = "Tokyo"
        viewModel.destination = "Tokyo, Japan"

        let success = await viewModel.save()

        XCTAssertTrue(success)
        let createCount = await mock.createCallCount
        XCTAssertEqual(createCount, 1)
        let updateCount = await mock.updateCallCount
        XCTAssertEqual(updateCount, 0)
        let stored = try? await mock.fetchTrips()
        XCTAssertEqual(stored?.first?.title, "Tokyo")
        XCTAssertEqual(stored?.first?.destination, "Tokyo, Japan")
    }

    func testSave_TrimsWhitespaceOnTitleAndDestination() async {
        let mock = MockTripRepository()
        let viewModel = TripEditorViewModel(mode: .create, repository: mock)
        viewModel.title = "  Tokyo  "
        viewModel.destination = "  Tokyo, Japan  "

        _ = await viewModel.save()

        let stored = try? await mock.fetchTrips()
        XCTAssertEqual(stored?.first?.title, "Tokyo")
        XCTAssertEqual(stored?.first?.destination, "Tokyo, Japan")
    }

    func testSave_EditMode_CallsUpdateWithSameId() async {
        let original = Trip(
            title: "Original",
            destination: "City",
            startDate: Date(),
            endDate: Date().addingTimeInterval(86_400)
        )
        let mock = MockTripRepository()
        await mock.seed([original])

        let viewModel = TripEditorViewModel(mode: .edit(original), repository: mock)
        viewModel.title = "Edited"

        let success = await viewModel.save()

        XCTAssertTrue(success)
        let updateCount = await mock.updateCallCount
        XCTAssertEqual(updateCount, 1)
        let createCount = await mock.createCallCount
        XCTAssertEqual(createCount, 0)
        let stored = try? await mock.trip(with: original.id)
        XCTAssertEqual(stored?.id, original.id)
        XCTAssertEqual(stored?.title, "Edited")
        XCTAssertEqual(stored?.createdAt, original.createdAt)
    }

    func testSave_EmptyTitle_FailsValidationAndDoesNotCallRepository() async {
        let mock = MockTripRepository()
        let viewModel = TripEditorViewModel(mode: .create, repository: mock)
        viewModel.title = "   "
        viewModel.destination = "Tokyo"

        let success = await viewModel.save()

        XCTAssertFalse(success)
        XCTAssertEqual(viewModel.errorMessage, TripValidationError.missingTitle.errorDescription)
        let createCount = await mock.createCallCount
        XCTAssertEqual(createCount, 0)
    }

    func testSave_EmptyDestination_FailsValidation() async {
        let mock = MockTripRepository()
        let viewModel = TripEditorViewModel(mode: .create, repository: mock)
        viewModel.title = "Tokyo"
        viewModel.destination = ""

        let success = await viewModel.save()

        XCTAssertFalse(success)
        XCTAssertEqual(viewModel.errorMessage, TripValidationError.missingDestination.errorDescription)
    }

    func testSave_EndBeforeStart_FailsValidation() async {
        let mock = MockTripRepository()
        let viewModel = TripEditorViewModel(mode: .create, repository: mock)
        viewModel.title = "Tokyo"
        viewModel.destination = "Tokyo, Japan"
        viewModel.startDate = Date()
        viewModel.endDate = Date().addingTimeInterval(-86_400)

        let success = await viewModel.save()

        XCTAssertFalse(success)
        XCTAssertEqual(
            viewModel.errorMessage,
            TripValidationError.endDateBeforeStartDate.errorDescription
        )
    }

    func testIsSaveDisabled_WhenTitleEmpty_ReturnsTrue() {
        let mock = MockTripRepository()
        let viewModel = TripEditorViewModel(mode: .create, repository: mock)
        viewModel.title = ""
        viewModel.destination = "Tokyo"
        XCTAssertTrue(viewModel.isSaveDisabled)
    }

    func testIsSaveDisabled_WhenFieldsValid_ReturnsFalse() {
        let mock = MockTripRepository()
        let viewModel = TripEditorViewModel(mode: .create, repository: mock)
        viewModel.title = "Tokyo"
        viewModel.destination = "Tokyo, Japan"
        XCTAssertFalse(viewModel.isSaveDisabled)
    }
}
