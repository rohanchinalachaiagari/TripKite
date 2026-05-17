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
            repository: mock,
            notificationService: MockNotificationSchedulingService()
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
            repository: mock,
            notificationService: MockNotificationSchedulingService()
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

        let vm = ItineraryItemEditorViewModel(
            mode: .edit(original),
            repository: mock,
            notificationService: MockNotificationSchedulingService()
        )
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
            repository: mock,
            notificationService: MockNotificationSchedulingService()
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
            repository: mock,
            notificationService: MockNotificationSchedulingService()
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
            repository: mock,
            notificationService: MockNotificationSchedulingService()
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
            repository: mock,
            notificationService: MockNotificationSchedulingService()
        )
        vm.title = ""
        XCTAssertTrue(vm.isSaveDisabled)
    }

    func testIsSaveDisabled_WhenFieldsValid_ReturnsFalse() {
        let mock = MockItineraryRepository()
        let vm = ItineraryItemEditorViewModel(
            mode: .create(tripId: UUID(), defaultStartDate: Date()),
            repository: mock,
            notificationService: MockNotificationSchedulingService()
        )
        vm.title = "Flight"
        XCTAssertFalse(vm.isSaveDisabled)
    }

    // MARK: - Reminder scheduling

    func testSave_WithReminderOption_SchedulesAfterCancel() async {
        let tripId = UUID()
        let mock = MockItineraryRepository()
        await mock.seedTripIds([tripId])
        let notifications = MockNotificationSchedulingService()

        let futureStart = Date().addingTimeInterval(3600)
        let vm = ItineraryItemEditorViewModel(
            mode: .create(tripId: tripId, defaultStartDate: futureStart),
            repository: mock,
            notificationService: notifications
        )
        vm.title = "Flight"
        vm.reminderOption = .minutesBefore15

        let success = await vm.save()
        XCTAssertTrue(success)

        let schedules = await notifications.scheduleCalls
        let cancellations = await notifications.itemCancellations
        XCTAssertEqual(schedules.count, 1)
        XCTAssertEqual(schedules.first?.reminderOffset, 15 * 60)
        XCTAssertEqual(cancellations.count, 1, "Editor should always cancel before scheduling")
    }

    func testSave_WithoutReminder_CancelsButDoesNotSchedule() async {
        let tripId = UUID()
        let mock = MockItineraryRepository()
        await mock.seedTripIds([tripId])
        let notifications = MockNotificationSchedulingService()

        let vm = ItineraryItemEditorViewModel(
            mode: .create(tripId: tripId, defaultStartDate: Date()),
            repository: mock,
            notificationService: notifications
        )
        vm.title = "Quick stop"
        vm.reminderOption = .none

        let success = await vm.save()
        XCTAssertTrue(success)

        let schedules = await notifications.scheduleCalls
        let cancellations = await notifications.itemCancellations
        XCTAssertTrue(schedules.isEmpty)
        XCTAssertEqual(cancellations.count, 1)
    }

    func testSave_EditMode_RemovingReminder_CancelsAndDoesNotSchedule() async {
        let existing = ItineraryItem(
            tripId: UUID(),
            title: "Old",
            type: .activity,
            startDate: Date().addingTimeInterval(7200),
            reminderOffset: 1800
        )
        let mock = MockItineraryRepository()
        await mock.seed([existing])
        let notifications = MockNotificationSchedulingService()

        let vm = ItineraryItemEditorViewModel(
            mode: .edit(existing),
            repository: mock,
            notificationService: notifications
        )
        vm.reminderOption = .none

        let success = await vm.save()
        XCTAssertTrue(success)

        let schedules = await notifications.scheduleCalls
        let cancellations = await notifications.itemCancellations
        XCTAssertTrue(schedules.isEmpty)
        XCTAssertEqual(cancellations, [existing.id])
    }

    func testSave_WhenScheduleThrowsReminderInPast_StillSucceeds() async {
        let tripId = UUID()
        let mock = MockItineraryRepository()
        await mock.seedTripIds([tripId])
        let notifications = MockNotificationSchedulingService()
        await notifications.setScheduleError(NotificationSchedulingError.reminderDateInPast)

        let vm = ItineraryItemEditorViewModel(
            mode: .create(tripId: tripId, defaultStartDate: Date().addingTimeInterval(60)),
            repository: mock,
            notificationService: notifications
        )
        vm.title = "Right now"
        vm.reminderOption = .hourBefore1

        let success = await vm.save()

        XCTAssertTrue(success)
        XCTAssertNil(vm.errorMessage)
    }

    // MARK: - Outside trip date confirmation

    func testSave_InRangeItem_SavesImmediately() async {
        let tripId = UUID()
        let mock = MockItineraryRepository()
        await mock.seedTripIds([tripId])

        let (tripRange, insideStart) = Self.tripRangeAndInsideStart()
        let vm = ItineraryItemEditorViewModel(
            mode: .create(tripId: tripId, defaultStartDate: insideStart),
            repository: mock,
            notificationService: MockNotificationSchedulingService(),
            tripRange: tripRange
        )
        vm.title = "Inside"

        let success = await vm.save()

        XCTAssertTrue(success)
        XCTAssertFalse(vm.pendingOutsideRangeConfirmation)
        let createCount = await mock.createCallCount
        XCTAssertEqual(createCount, 1)
    }

    func testSave_OutOfRange_DoesNotPersist_SetsConfirmationFlag() async {
        let tripId = UUID()
        let mock = MockItineraryRepository()
        await mock.seedTripIds([tripId])

        let (tripRange, _) = Self.tripRangeAndInsideStart()
        let outsideStart = Calendar.current.date(byAdding: .day, value: -5, to: tripRange.lowerBound)!

        let vm = ItineraryItemEditorViewModel(
            mode: .create(tripId: tripId, defaultStartDate: outsideStart),
            repository: mock,
            notificationService: MockNotificationSchedulingService(),
            tripRange: tripRange
        )
        vm.title = "Outside"

        let success = await vm.save()

        XCTAssertFalse(success)
        XCTAssertTrue(vm.pendingOutsideRangeConfirmation)
        let createCount = await mock.createCallCount
        XCTAssertEqual(createCount, 0)
    }

    func testConfirmSaveAnyway_AfterOutOfRangeWarning_Persists() async {
        let tripId = UUID()
        let mock = MockItineraryRepository()
        await mock.seedTripIds([tripId])

        let (tripRange, _) = Self.tripRangeAndInsideStart()
        let outsideStart = Calendar.current.date(byAdding: .day, value: 10, to: tripRange.upperBound)!

        let vm = ItineraryItemEditorViewModel(
            mode: .create(tripId: tripId, defaultStartDate: outsideStart),
            repository: mock,
            notificationService: MockNotificationSchedulingService(),
            tripRange: tripRange
        )
        vm.title = "Outside"

        _ = await vm.save()
        XCTAssertTrue(vm.pendingOutsideRangeConfirmation)

        let confirmed = await vm.confirmSaveAnyway()

        XCTAssertTrue(confirmed)
        XCTAssertFalse(vm.pendingOutsideRangeConfirmation)
        let createCount = await mock.createCallCount
        XCTAssertEqual(createCount, 1)
    }

    func testSave_EditMode_OutOfRange_AlsoTriggersConfirmation() async {
        let (tripRange, _) = Self.tripRangeAndInsideStart()
        let outsideStart = Calendar.current.date(byAdding: .day, value: 20, to: tripRange.upperBound)!
        let existing = ItineraryItem(
            tripId: UUID(),
            title: "Existing",
            type: .activity,
            startDate: outsideStart
        )
        let mock = MockItineraryRepository()
        await mock.seed([existing])

        let vm = ItineraryItemEditorViewModel(
            mode: .edit(existing),
            repository: mock,
            notificationService: MockNotificationSchedulingService(),
            tripRange: tripRange
        )

        let success = await vm.save()

        XCTAssertFalse(success)
        XCTAssertTrue(vm.pendingOutsideRangeConfirmation)
        let updateCount = await mock.updateCallCount
        XCTAssertEqual(updateCount, 0)
    }

    // Provides a 5-day trip range and a date guaranteed to fall inside it,
    // independent of the current wall-clock date.
    private static func tripRangeAndInsideStart() -> (ClosedRange<Date>, Date) {
        let calendar = Calendar(identifier: .gregorian)
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 10
        components.hour = 0
        let start = calendar.date(from: components)!
        let end = calendar.date(byAdding: .day, value: 4, to: start)!
        let inside = calendar.date(byAdding: .hour, value: 36, to: start)!
        return (start...end, inside)
    }

    func testReminderOption_FirstChangeFromNone_PromptsForAuthorization() async {
        let tripId = UUID()
        let mock = MockItineraryRepository()
        await mock.seedTripIds([tripId])
        let notifications = MockNotificationSchedulingService()
        await notifications.setAuthorizationStatus(.notDetermined)

        let vm = ItineraryItemEditorViewModel(
            mode: .create(tripId: tripId, defaultStartDate: Date()),
            repository: mock,
            notificationService: notifications
        )
        await vm.loadAuthorizationStatus()

        vm.reminderOption = .minutesBefore15
        await Task.yield()
        // The didSet kicks off an async task; give it a chance to run.
        try? await Task.sleep(nanoseconds: 50_000_000)

        let requestCount = await notifications.authorizationRequestCount
        XCTAssertEqual(requestCount, 1)
    }
}
