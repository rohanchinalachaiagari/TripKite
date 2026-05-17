import SwiftUI

struct ItineraryItemEditorView: View {
    @StateObject private var viewModel: ItineraryItemEditorViewModel
    private let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss

    init(
        mode: ItineraryItemEditorViewModel.Mode,
        repository: ItineraryRepository,
        notificationService: NotificationSchedulingService,
        tripRange: ClosedRange<Date>? = nil,
        onSaved: @escaping () -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: ItineraryItemEditorViewModel(
                mode: mode,
                repository: repository,
                notificationService: notificationService,
                tripRange: tripRange
            )
        )
        self.onSaved = onSaved
    }

    var body: some View {
        Form {
            Section("Item") {
                TextField("Title", text: $viewModel.title)
                Picker("Type", selection: $viewModel.type) {
                    ForEach(ItineraryType.allCases) { type in
                        Label(type.displayName, systemImage: type.systemImageName).tag(type)
                    }
                }
            }

            Section("Schedule") {
                DatePicker("Starts", selection: $viewModel.startDate)
                Toggle("Has end time", isOn: $viewModel.hasEndDate)
                if viewModel.hasEndDate {
                    DatePicker("Ends", selection: $viewModel.endDate, in: viewModel.startDate...)
                }
            }

            Section("Location") {
                TextField("Location name", text: $viewModel.locationName)
                TextField("Address", text: $viewModel.address)
            }

            Section("Reminder") {
                Picker("Remind me", selection: $viewModel.reminderOption) {
                    ForEach(ReminderOption.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                if viewModel.authorizationStatus == .denied && viewModel.reminderOption != .none {
                    Text("Notifications are turned off for TripKit. Enable them in Settings to receive reminders.")
                        .font(TKTypography.metadata)
                        .foregroundStyle(TKColors.textSecondary)
                }
            }

            Section("Details") {
                TextField("Confirmation number", text: $viewModel.confirmationNumber)
                TextField("Notes", text: $viewModel.notes, axis: .vertical)
                    .lineLimit(3...6)
            }
        }
        .navigationTitle(viewModel.mode.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadAuthorizationStatus()
        }
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
            "Couldn't save item",
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
        .alert(
            "Outside trip dates",
            isPresented: $viewModel.pendingOutsideRangeConfirmation
        ) {
            Button("Cancel", role: .cancel) { }
            Button("Save Anyway") {
                Task {
                    let success = await viewModel.confirmSaveAnyway()
                    if success {
                        onSaved()
                        dismiss()
                    }
                }
            }
        } message: {
            Text("This item starts outside your trip dates. Save it anyway?")
        }
    }
}

#if DEBUG
#Preview("Create") {
    let stack = CoreDataStack.previewSeeded()
    NavigationStack {
        ItineraryItemEditorView(
            mode: .create(tripId: MockData.tokyoTrip.id, defaultStartDate: MockData.tokyoTrip.startDate),
            repository: CoreDataItineraryRepository(stack: stack),
            notificationService: UserNotificationSchedulingService(),
            onSaved: {}
        )
    }
}

#Preview("Edit") {
    let stack = CoreDataStack.previewSeeded()
    NavigationStack {
        ItineraryItemEditorView(
            mode: .edit(MockData.tokyoItinerary[0]),
            repository: CoreDataItineraryRepository(stack: stack),
            notificationService: UserNotificationSchedulingService(),
            onSaved: {}
        )
    }
}
#endif
