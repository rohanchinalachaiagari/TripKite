import XCTest
@testable import TripKit

@MainActor
final class ItineraryItemEditorViewModelTests: XCTestCase {

    func testSave_CreateMode_CallsCreate() async {
        let tripId = UUID()
        let mock = MockItineraryRepository()
        await mock.seedTripIds([tripId])

        let vm = ItineraryItemEditorViewModel(
            mode: .create(tripId: tripId, defaultStartDate: Date()),
            repository: mock
        )
        vm.title = "Flight"

        let success = await vm.save()

        XCTAssertTrue(success)
        let createCount = await mock.createCallCount
        XCTAssertEqual(createCount, 1)
        let updateCount = await mock.updateCallCount
        XCTAssertEqual(updateCount, 0)
    }

    func testSave_TrimsWhitespaceOnTextFields() async {
        let tripId = UUID()
        let mock = MockItineraryRepository()
        await mock.seedTripIds([tripId])

        let vm = ItineraryItemEditorViewModel(
            mode: .create(tripId: tripId, defaultStartDate: Date()),
            repository: mock
        )
        vm.title = "  Flight  "
        vm.locationName = "  SFO  "
        vm.address = "  780 S Airport Blvd  "
        vm.confirmationNumber = "  ANA-123  "

        _ = await vm.save()

        let stored = await mock.storage.values.first
        XCTAssertEqual(stored?.title, "Flight")
        XCTAssertEqual(stored?.locationName, "SFO")
        XCTAssertEqual(stored?.address, "780 S Airport Blvd")
        XCTAssertEqual(stored?.confirmationNumber, "ANA-123")
    }

    func testSave_EditMode_CallsUpdateWithSameIdAndCreatedAt() async {
        let original = ItineraryItem(
            tripId: UUID(),
            title: "Original",
            type: .activity,
            startDate: Date()
        )
        let mock = MockItineraryRepository()
        await mock.seed([original])

        let vm = ItineraryItemEditorViewModel(mode: .edit(original), repository: mock)
        vm.title = "Updated"

        let success = await vm.save()

        XCTAssertTrue(success)
        let updateCount = await mock.updateCallCount
        XCTAssertEqual(updateCount, 1)
        let createCount = await mock.createCallCount
        XCTAssertEqual(createCount, 0)
        let stored = await mock.storage[original.id]
        XCTAssertEqual(stored?.title, "Updated")
        XCTAssertEqual(stored?.createdAt, original.createdAt)
    }

    func testSave_EmptyTitle_FailsValidation() async {
        let tripId = UUID()
        let mock = MockItineraryRepository()
        await mock.seedTripIds([tripId])

        let vm = ItineraryItemEditorViewModel(
            mode: .create(tripId: tripId, defaultStartDate: Date()),
            repository: mock
        )
        vm.title = "   "

        let success = await vm.save()

        XCTAssertFalse(success)
        XCTAssertEqual(vm.errorMessage, ItineraryValidationError.missingTitle.errorDescription)
        let createCount = await mock.createCallCount
        XCTAssertEqual(createCount, 0)
    }

    func testSave_EndBeforeStart_FailsValidation() async {
        let tripId = UUID()
        let mock = MockItineraryRepository()
        await mock.seedTripIds([tripId])

        let start = Date()
        let vm = ItineraryItemEditorViewModel(
            mode: .create(tripId: tripId, defaultStartDate: start),
            repository: mock
        )
        vm.title = "Flight"
        vm.hasEndDate = true
        vm.endDate = start.addingTimeInterval(-3600)

        let success = await vm.save()

        XCTAssertFalse(success)
        XCTAssertEqual(vm.errorMessage, ItineraryValidationError.endDateBeforeStartDate.errorDescription)
    }

    func testSave_HasEndDateOff_PersistsNilEndDate() async {
        let tripId = UUID()
        let mock = MockItineraryRepository()
        await mock.seedTripIds([tripId])

        let vm = ItineraryItemEditorViewModel(
            mode: .create(tripId: tripId, defaultStartDate: Date()),
            repository: mock
        )
        vm.title = "Quick stop"
        vm.hasEndDate = false

        let success = await vm.save()

        XCTAssertTrue(success)
        let stored = await mock.storage.values.first
        XCTAssertNil(stored?.endDate)
    }

    func testIsSaveDisabled_WhenTitleEmpty_ReturnsTrue() {
        let mock = MockItineraryRepository()
        let vm = ItineraryItemEditorViewModel(
            mode: .create(tripId: UUID(), defaultStartDate: Date()),
            repository: mock
        )
        vm.title = ""
        XCTAssertTrue(vm.isSaveDisabled)
    }

    func testIsSaveDisabled_WhenFieldsValid_ReturnsFalse() {
        let mock = MockItineraryRepository()
        let vm = ItineraryItemEditorViewModel(
            mode: .create(tripId: UUID(), defaultStartDate: Date()),
            repository: mock
        )
        vm.title = "Flight"
        XCTAssertFalse(vm.isSaveDisabled)
    }
}
