import SwiftUI

struct ItineraryItemEditorView: View {
    @StateObject private var viewModel: ItineraryItemEditorViewModel
    private let onSaved: () -> Void
    private let associatedDocuments: [TravelDocument]
    private let resolveDocumentURL: ((TravelDocument) -> URL?)?

    @Environment(\.dismiss) private var dismiss
    @State private var previewURL: URL?

    init(
        mode: ItineraryItemEditorViewModel.Mode,
        repository: ItineraryRepository,
        notificationService: NotificationSchedulingService,
        locationActions: LocationActionService,
        tripRange: ClosedRange<Date>? = nil,
        defaultReminderOption: ReminderOption = .none,
        associatedDocuments: [TravelDocument] = [],
        resolveDocumentURL: ((TravelDocument) -> URL?)? = nil,
        onSaved: @escaping () -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: ItineraryItemEditorViewModel(
                mode: mode,
                repository: repository,
                notificationService: notificationService,
                locationActions: locationActions,
                tripRange: tripRange,
                defaultReminderOption: defaultReminderOption
            )
        )
        self.associatedDocuments = associatedDocuments
        self.resolveDocumentURL = resolveDocumentURL
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
                locationNameField
                addressField
                openInMapsButton
            }

            Section("Reminder") {
                Picker("Remind me", selection: $viewModel.reminderOption) {
                    ForEach(ReminderOption.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                if viewModel.authorizationStatus == .denied && viewModel.reminderOption != .none {
                    Text("Notifications are turned off for TripKite. Enable them in Settings to receive reminders.")
                        .font(TKTypography.metadata)
                        .foregroundStyle(TKColors.textSecondary)
                }
            }

            Section("Details") {
                TextField("Confirmation number", text: $viewModel.confirmationNumber)
                TextField("Notes", text: $viewModel.notes, axis: .vertical)
                    .lineLimit(3...6)
            }

            if !associatedDocuments.isEmpty {
                Section("Documents") {
                    ForEach(associatedDocuments) { document in
                        documentRow(for: document)
                    }
                }
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
        .quickLookSheet(url: $previewURL)
    }

    // Location-name and address fields each carry an inline trailing copy
    // button that surfaces only when the live binding has non-blank content.
    // The button uses `.borderless` so taps on the symbol don't compete with
    // taps on the surrounding row, and the field stays the primary tap
    // target for editing.

    private var locationNameField: some View {
        HStack(spacing: TKSpacing.sm) {
            TextField("Location name", text: $viewModel.locationName)
            if viewModel.availableLocationActions.contains(.copyLocationName) {
                copyFieldButton(
                    field: .name,
                    label: "Copy location name"
                ) {
                    viewModel.copyLocationName()
                }
            }
        }
    }

    private var addressField: some View {
        HStack(spacing: TKSpacing.sm) {
            TextField("Address", text: $viewModel.address)
            if viewModel.availableLocationActions.contains(.copyAddress) {
                copyFieldButton(
                    field: .address,
                    label: "Copy address"
                ) {
                    viewModel.copyAddress()
                }
            }
        }
    }

    @ViewBuilder
    private var openInMapsButton: some View {
        if viewModel.availableLocationActions.contains(.openInMaps) {
            Button {
                viewModel.openInMaps()
            } label: {
                Label("Open in Maps", systemImage: "map")
            }
        }
    }

    private func copyFieldButton(
        field: CopiedLocationField,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        let copied = viewModel.recentlyCopiedField == field
        return Button(action: action) {
            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                .font(TKTypography.cardSubtitle)
                .foregroundStyle(copied ? TKColors.brand : TKColors.textSecondary)
                // Expand the hit area to the HIG minimum without enlarging the
                // visible glyph. The Image itself stays at its natural size;
                // .frame + .contentShape make the surrounding 44pt region
                // tappable.
                .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(copied ? "Copied" : label)
        .animation(.easeInOut(duration: 0.15), value: copied)
    }

    // Compact read-only document row. Document management (rename, delete,
    // reassign) stays in the trip-level Documents section. Tap previews via
    // QuickLook using the same flow the trip-level section uses.
    private func documentRow(for document: TravelDocument) -> some View {
        DocumentRowView(
            document: document,
            subtitle: DocumentRowSubtitle.make(for: document),
            onTap: { previewURL = resolveDocumentURL?(document) }
        )
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
            locationActions: SystemLocationActionService(),
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
            locationActions: SystemLocationActionService(),
            onSaved: {}
        )
    }
}
#endif
