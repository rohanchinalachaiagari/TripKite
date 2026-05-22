import XCTest
@testable import TripKite

final class LocalDataManagementServiceTests: XCTestCase {

    func testClearAllData_OnEmptyStore_IsNoOpAndResetsSettings() async throws {
        let env = makeEnv()
        try await env.service.clearAllData()

        XCTAssertEqual(env.settings.resetCount, 1)
    }

    func testClearAllData_CancelsNotificationsForEachTrip() async throws {
        let env = makeEnv()
        let tripA = makeTrip(title: "A")
        let tripB = makeTrip(title: "B", startOffset: 10)
        await env.trips.seed([tripA, tripB])

        try await env.service.clearAllData()

        let cancellations = await env.notifications.tripCancellations
        XCTAssertEqual(Set(cancellations), Set([tripA.id, tripB.id]))
    }

    func testClearAllData_DeletesAllTrips() async throws {
        let env = makeEnv()
        let trip = makeTrip(title: "ToDelete")
        await env.trips.seed([trip])

        try await env.service.clearAllData()

        let remaining = try await env.trips.fetchTrips()
        XCTAssertTrue(remaining.isEmpty)
    }

    func testClearAllData_DeletesDocumentFilesForEachTrip() async throws {
        let env = makeEnv()
        let trip = makeTrip(title: "WithDocs")
        await env.trips.seed([trip])

        let doc1 = TravelDocument(
            tripId: trip.id,
            fileName: "A.pdf",
            localRelativePath: "Attachments/a.pdf",
            fileType: "pdf"
        )
        let doc2 = TravelDocument(
            tripId: trip.id,
            fileName: "B.pdf",
            localRelativePath: "Attachments/b.pdf",
            fileType: "pdf"
        )
        await env.documents.seed([doc1, doc2])

        try await env.service.clearAllData()

        let deletedPaths = await env.storage.deleteCalls
        XCTAssertEqual(Set(deletedPaths), Set([doc1.localRelativePath, doc2.localRelativePath]))
    }

    func testClearAllData_RunsGlobalNotificationSweep() async throws {
        let env = makeEnv()
        let tripA = makeTrip(title: "A")
        let tripB = makeTrip(title: "B", startOffset: 10)
        await env.trips.seed([tripA, tripB])

        try await env.service.clearAllData()

        let sweepCount = await env.notifications.cancelAllCount
        XCTAssertEqual(sweepCount, 1, "Clear All Data should run a single global sweep after the per-trip loop")
    }

    func testClearAllData_OnEmptyStore_StillRunsGlobalSweep() async throws {
        let env = makeEnv()
        try await env.service.clearAllData()

        // Even with no trips, the sweep should run so any orphaned pending
        // notifications from a prior crash get cleared.
        let sweepCount = await env.notifications.cancelAllCount
        XCTAssertEqual(sweepCount, 1)
    }

    func testClearAllData_ResetsSettings() async throws {
        let env = makeEnv()
        env.settings.setDefaultReminderOption(.hourBefore1)

        try await env.service.clearAllData()

        XCTAssertEqual(env.settings.resetCount, 1)
        XCTAssertEqual(env.settings.defaultReminderOption(), .none)
    }

    func testClearAllData_WhenTripDeleteFails_PropagatesError() async throws {
        let env = makeEnv()
        let trip = makeTrip(title: "Stuck")
        await env.trips.seed([trip])

        struct BoomError: Error {}
        await env.trips.setDeleteError(BoomError())

        do {
            try await env.service.clearAllData()
            XCTFail("Expected clearAllData to throw")
        } catch {
            // Settings reset happens AFTER all trips are deleted, so a failed
            // delete should prevent the settings reset.
            XCTAssertEqual(env.settings.resetCount, 0)
        }
    }

    // MARK: - Helpers

    private struct Env {
        let trips: MockTripRepository
        let documents: MockDocumentRepository
        let storage: MockDocumentStorageService
        let notifications: MockNotificationSchedulingService
        let settings: MockSettingsStore
        let service: LocalDataManagementService
    }

    private func makeEnv() -> Env {
        let trips = MockTripRepository()
        let documents = MockDocumentRepository()
        let storage = MockDocumentStorageService()
        let notifications = MockNotificationSchedulingService()
        let settings = MockSettingsStore()
        let service = LocalDataManagementService(
            tripRepository: trips,
            documentRepository: documents,
            documentStorage: storage,
            notificationService: notifications,
            settingsStore: settings
        )
        return Env(
            trips: trips,
            documents: documents,
            storage: storage,
            notifications: notifications,
            settings: settings,
            service: service
        )
    }

    private func makeTrip(title: String, startOffset: Int = 1) -> Trip {
        let start = Calendar.current.date(byAdding: .day, value: startOffset, to: Date()) ?? Date()
        let end = Calendar.current.date(byAdding: .day, value: startOffset + 3, to: Date()) ?? start
        return Trip(title: title, destination: "\(title) City", startDate: start, endDate: end)
    }
}
