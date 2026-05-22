import Foundation
import Combine

// Identifies the inline copy button that the user most recently tapped, so
// the editor view can swap that field's copy icon to a checkmark for a brief
// confirmation window. Cleared automatically after a short delay.
enum CopiedLocationField: Hashable {
    case name
    case address
}

@MainActor
final class ItineraryItemEditorViewModel: ObservableObject {
    enum Mode {
        case create(tripId: UUID, defaultStartDate: Date)
        case edit(ItineraryItem)

        var navigationTitle: String {
            switch self {
            case .create: return "New Item"
            case .edit: return "Edit Item"
            }
        }
    }

    @Published var title: String
    @Published var type: ItineraryType
    @Published var startDate: Date
    @Published var hasEndDate: Bool
    @Published var endDate: Date
    @Published var locationName: String
    @Published var address: String
    @Published var confirmationNumber: String
    @Published var notes: String
    @Published var reminderOption: ReminderOption {
        didSet {
            let previous = oldValue
            Task { await handleReminderOptionChange(from: previous) }
        }
    }
    @Published private(set) var authorizationStatus: NotificationAuthorizationStatus = .notDetermined
    @Published var errorMessage: String?
    @Published var pendingOutsideRangeConfirmation: Bool = false
    @Published private(set) var isSaving = false
    // Drives the inline "Copied" confirmation on the trailing copy icons.
    // Reset to nil after a short delay; rapid retaps cancel the pending
    // reset so the user never sees a stale checkmark on the wrong field.
    @Published private(set) var recentlyCopiedField: CopiedLocationField?

    let mode: Mode
    private let tripId: UUID
    private let tripRange: ClosedRange<Date>?
    private let repository: ItineraryRepository
    private let notificationService: NotificationSchedulingService
    private let locationActions: LocationActionService
    private let now: @Sendable () -> Date

    private var copiedResetTask: Task<Void, Never>?
    private let copyFeedbackDuration: Duration = .milliseconds(1300)

    init(
        mode: Mode,
        repository: ItineraryRepository,
        notificationService: NotificationSchedulingService,
        locationActions: LocationActionService,
        tripRange: ClosedRange<Date>? = nil,
        defaultReminderOption: ReminderOption = .none,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.mode = mode
        self.tripRange = tripRange
        self.repository = repository
        self.notificationService = notificationService
        self.locationActions = locationActions
        self.now = now

        switch mode {
        case .create(let tripId, let defaultStartDate):
            self.tripId = tripId
            self.title = ""
            self.type = .activity
            self.startDate = defaultStartDate
            self.hasEndDate = false
            self.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: defaultStartDate) ?? defaultStartDate
            self.locationName = ""
            self.address = ""
            self.confirmationNumber = ""
            self.notes = ""
            // Use the user's persisted default. didSet does not fire from init,
            // so the lazy-authorization Task isn't spawned here — the editor's
            // existing flow handles it if/when the user changes the picker.
            self.reminderOption = defaultReminderOption
        case .edit(let item):
            self.tripId = item.tripId
            self.title = item.title
            self.type = item.type
            self.startDate = item.startDate
            self.hasEndDate = item.endDate != nil
            self.endDate = item.endDate
                ?? (Calendar.current.date(byAdding: .hour, value: 1, to: item.startDate) ?? item.startDate)
            self.locationName = item.locationName
            self.address = item.address
            self.confirmationNumber = item.confirmationNumber
            self.notes = item.notes
            self.reminderOption = ReminderOption.match(offset: item.reminderOffset)
        }
    }

    func loadAuthorizationStatus() async {
        authorizationStatus = await notificationService.currentAuthorizationStatus()
    }

    private func handleReminderOptionChange(from oldValue: ReminderOption) async {
        guard oldValue == .none, reminderOption != .none else { return }
        guard authorizationStatus == .notDetermined else { return }
        _ = await notificationService.requestAuthorization()
        authorizationStatus = await notificationService.currentAuthorizationStatus()
    }

    var isSaveDisabled: Bool {
        isSaving
            || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || (hasEndDate && endDate < startDate)
    }

    // Calendar-day comparison so that an item scheduled in the afternoon of a
    // trip's departure day is still considered "inside" even when endDate is
    // stored as midnight of that day.
    var isStartDateInsideTripRange: Bool {
        guard let tripRange else { return true }
        let calendar = Calendar.current
        let itemDay = calendar.startOfDay(for: startDate)
        let tripStartDay = calendar.startOfDay(for: tripRange.lowerBound)
        let tripEndDay = calendar.startOfDay(for: tripRange.upperBound)
        return itemDay >= tripStartDay && itemDay <= tripEndDay
    }

    func save() async -> Bool {
        do {
            try ItineraryValidator.validate(
                title: title,
                startDate: startDate,
                endDate: hasEndDate ? endDate : nil,
                reminderOffset: reminderOption.offset
            )
        } catch {
            errorMessage = error.localizedDescription
            return false
        }

        if !isStartDateInsideTripRange {
            pendingOutsideRangeConfirmation = true
            return false
        }

        return await performSave()
    }

    func confirmSaveAnyway() async -> Bool {
        pendingOutsideRangeConfirmation = false
        return await performSave()
    }

    private func performSave() async -> Bool {
        isSaving = true
        defer { isSaving = false }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLocation = locationName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedConfirmation = confirmationNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedEnd: Date? = hasEndDate ? endDate : nil
        let resolvedOffset = reminderOption.offset
        let timestamp = now()

        let persistedItem: ItineraryItem
        do {
            switch mode {
            case .create:
                let item = ItineraryItem(
                    tripId: tripId,
                    title: trimmedTitle,
                    type: type,
                    startDate: startDate,
                    endDate: resolvedEnd,
                    locationName: trimmedLocation,
                    address: trimmedAddress,
                    confirmationNumber: trimmedConfirmation,
                    notes: notes,
                    reminderOffset: resolvedOffset,
                    createdAt: timestamp,
                    updatedAt: timestamp
                )
                try await repository.createItem(item)
                persistedItem = item
            case .edit(let existing):
                let updated = ItineraryItem(
                    id: existing.id,
                    tripId: existing.tripId,
                    title: trimmedTitle,
                    type: type,
                    startDate: startDate,
                    endDate: resolvedEnd,
                    locationName: trimmedLocation,
                    address: trimmedAddress,
                    confirmationNumber: trimmedConfirmation,
                    notes: notes,
                    reminderOffset: resolvedOffset,
                    createdAt: existing.createdAt,
                    updatedAt: timestamp
                )
                try await repository.updateItem(updated)
                persistedItem = updated
            }
        } catch {
            errorMessage = error.localizedDescription
            return false
        }

        // Always cancel any previous reminder for this item, then schedule a fresh
        // one if the user has a reminder configured. Scheduling errors (e.g., the
        // reminder time has already passed) are non-fatal — the item is saved.
        await notificationService.cancelReminder(forItemId: persistedItem.id)
        if resolvedOffset != nil {
            try? await notificationService.scheduleReminder(for: persistedItem)
        }

        errorMessage = nil
        return true
    }

    // MARK: - Location quick-actions
    //
    // Reads the live `@Published` bindings (which may include unsaved edits)
    // so users can copy an address they just typed. The service trims the
    // values on the way out — these methods do not mutate view state.

    var availableLocationActions: Set<LocationAction> {
        LocationActionAvailability.actions(name: locationName, address: address)
    }

    func openInMaps() {
        locationActions.openInMaps(name: locationName, address: address)
    }

    func copyAddress() {
        locationActions.copy(text: address)
        markCopied(.address)
    }

    func copyLocationName() {
        locationActions.copy(text: locationName)
        markCopied(.name)
    }

    private func markCopied(_ field: CopiedLocationField) {
        copiedResetTask?.cancel()
        recentlyCopiedField = field
        let duration = copyFeedbackDuration
        copiedResetTask = Task { [weak self] in
            try? await Task.sleep(for: duration)
            if Task.isCancelled { return }
            await MainActor.run {
                self?.recentlyCopiedField = nil
            }
        }
    }
}
