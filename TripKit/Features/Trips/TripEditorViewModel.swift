import Combine
import Foundation

@MainActor
final class TripEditorViewModel: ObservableObject {
    enum Mode {
        case create
        case edit(Trip)

        var navigationTitle: String {
            switch self {
            case .create: return "New Trip"
            case .edit: return "Edit Trip"
            }
        }
    }

    @Published var title: String
    @Published var destination: String
    @Published var startDate: Date
    @Published var endDate: Date
    @Published var notes: String
    @Published var errorMessage: String?
    @Published private(set) var isSaving = false

    let mode: Mode
    private let repository: TripRepository
    private let now: @Sendable () -> Date

    init(
        mode: Mode,
        repository: TripRepository,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.mode = mode
        self.repository = repository
        self.now = now

        switch mode {
        case .create:
            let current = now()
            self.title = ""
            self.destination = ""
            self.startDate = current
            self.endDate = Calendar.current.date(byAdding: .day, value: 3, to: current) ?? current
            self.notes = ""
        case .edit(let trip):
            self.title = trip.title
            self.destination = trip.destination
            self.startDate = trip.startDate
            self.endDate = trip.endDate
            self.notes = trip.notes
        }
    }

    var isSaveDisabled: Bool {
        isSaving
            || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || destination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || endDate < startDate
    }

    func save() async -> Bool {
        do {
            try TripValidator.validate(
                title: title,
                destination: destination,
                startDate: startDate,
                endDate: endDate
            )
        } catch {
            errorMessage = error.localizedDescription
            return false
        }

        isSaving = true
        defer { isSaving = false }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDestination = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        let timestamp = now()

        do {
            switch mode {
            case .create:
                let trip = Trip(
                    title: trimmedTitle,
                    destination: trimmedDestination,
                    startDate: startDate,
                    endDate: endDate,
                    notes: notes,
                    createdAt: timestamp,
                    updatedAt: timestamp
                )
                try await repository.createTrip(trip)
            case .edit(let existing):
                let updated = Trip(
                    id: existing.id,
                    title: trimmedTitle,
                    destination: trimmedDestination,
                    startDate: startDate,
                    endDate: endDate,
                    notes: notes,
                    createdAt: existing.createdAt,
                    updatedAt: timestamp
                )
                try await repository.updateTrip(updated)
            }
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
