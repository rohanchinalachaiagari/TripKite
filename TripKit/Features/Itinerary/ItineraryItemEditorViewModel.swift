import Foundation
import Combine

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
    @Published var errorMessage: String?
    @Published private(set) var isSaving = false

    let mode: Mode
    private let tripId: UUID
    private let repository: ItineraryRepository
    private let now: @Sendable () -> Date

    init(
        mode: Mode,
        repository: ItineraryRepository,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.mode = mode
        self.repository = repository
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
        }
    }

    var isSaveDisabled: Bool {
        isSaving
            || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || (hasEndDate && endDate < startDate)
    }

    func save() async -> Bool {
        do {
            try ItineraryValidator.validate(
                title: title,
                startDate: startDate,
                endDate: hasEndDate ? endDate : nil
            )
        } catch {
            errorMessage = error.localizedDescription
            return false
        }

        isSaving = true
        defer { isSaving = false }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLocation = locationName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedConfirmation = confirmationNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedEnd: Date? = hasEndDate ? endDate : nil
        let timestamp = now()

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
                    createdAt: timestamp,
                    updatedAt: timestamp
                )
                try await repository.createItem(item)
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
                    createdAt: existing.createdAt,
                    updatedAt: timestamp
                )
                try await repository.updateItem(updated)
            }
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
