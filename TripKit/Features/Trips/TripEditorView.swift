import SwiftUI

struct TripEditorView: View {
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

    let mode: Mode

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var destination: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var notes: String

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .create:
            let now = Date()
            _title = State(initialValue: "")
            _destination = State(initialValue: "")
            _startDate = State(initialValue: now)
            _endDate = State(initialValue: Calendar.current.date(byAdding: .day, value: 3, to: now) ?? now)
            _notes = State(initialValue: "")
        case .edit(let trip):
            _title = State(initialValue: trip.title)
            _destination = State(initialValue: trip.destination)
            _startDate = State(initialValue: trip.startDate)
            _endDate = State(initialValue: trip.endDate)
            _notes = State(initialValue: trip.notes)
        }
    }

    private var isSaveDisabled: Bool {
        title.trimmingCharacters(in: .whitespaces).isEmpty
            || destination.trimmingCharacters(in: .whitespaces).isEmpty
            || endDate < startDate
    }

    var body: some View {
        Form {
            Section("Trip") {
                TextField("Title", text: $title)
                TextField("Destination", text: $destination)
            }

            Section("Dates") {
                DatePicker("Start", selection: $startDate, displayedComponents: .date)
                DatePicker("End", selection: $endDate, in: startDate..., displayedComponents: .date)
            }

            Section("Notes") {
                TextField("Optional notes", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }
        }
        .navigationTitle(mode.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { dismiss() }
                    .disabled(isSaveDisabled)
            }
        }
    }
}

#Preview("Create") {
    NavigationStack {
        TripEditorView(mode: .create)
    }
}

#Preview("Edit") {
    NavigationStack {
        TripEditorView(mode: .edit(MockData.tokyoTrip))
    }
}
