import SwiftUI

struct TripEditorView: View {
    @StateObject private var viewModel: TripEditorViewModel
    private let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss

    init(
        mode: TripEditorViewModel.Mode,
        repository: TripRepository,
        onSaved: @escaping () -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: TripEditorViewModel(mode: mode, repository: repository)
        )
        self.onSaved = onSaved
    }

    var body: some View {
        Form {
            Section("Trip") {
                TextField("Title", text: $viewModel.title)
                TextField("Destination", text: $viewModel.destination)
            }

            Section("Dates") {
                DatePicker("Start", selection: $viewModel.startDate, displayedComponents: .date)
                DatePicker(
                    "End",
                    selection: $viewModel.endDate,
                    in: viewModel.startDate...,
                    displayedComponents: .date
                )
            }

            Section("Notes") {
                TextField("Optional notes", text: $viewModel.notes, axis: .vertical)
                    .lineLimit(3...6)
            }
        }
        .navigationTitle(viewModel.mode.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
                    .disabled(viewModel.isSaving)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    Task {
                        let success = await viewModel.save()
                        if success {
                            onSaved()
                            dismiss()
                        }
                    }
                }
                .disabled(viewModel.isSaveDisabled)
            }
        }
        .alert(
            "Couldn't save trip",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            ),
            presenting: viewModel.errorMessage
        ) { _ in
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: { message in
            Text(message)
        }
    }
}

#if DEBUG
#Preview("Create") {
    NavigationStack {
        TripEditorView(
            mode: .create,
            repository: CoreDataTripRepository(stack: CoreDataStack(inMemory: true)),
            onSaved: {}
        )
    }
}

#Preview("Edit") {
    NavigationStack {
        TripEditorView(
            mode: .edit(MockData.tokyoTrip),
            repository: CoreDataTripRepository(stack: .previewSeeded()),
            onSaved: {}
        )
    }
}
#endif
