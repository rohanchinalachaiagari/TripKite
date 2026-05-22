import SwiftUI
import UniformTypeIdentifiers
import PhotosUI

struct TripDetailView: View {
    @StateObject private var viewModel: TripDetailViewModel
    @StateObject private var documentsViewModel: DocumentListViewModel
    private let focusItemId: UUID?
    private let itineraryRepository: ItineraryRepository
    private let tripRepository: TripRepository
    private let notificationService: NotificationSchedulingService
    private let documentRepository: DocumentRepository
    private let documentStorage: DocumentStorageService
    private let settingsStore: SettingsStore
    private let locationActions: LocationActionService
    private let onChange: () -> Void

    @State private var isEditingTrip = false
    @State private var isCreatingItem = false
    @State private var editingItem: ItineraryItem?
    @State private var isPickingFile = false
    @State private var isPickingPhoto = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var previewURL: URL?
    @State private var hasConsumedFocus = false

    init(
        trip: Trip,
        focusItemId: UUID? = nil,
        itineraryRepository: ItineraryRepository,
        tripRepository: TripRepository,
        notificationService: NotificationSchedulingService,
        documentRepository: DocumentRepository,
        documentStorage: DocumentStorageService,
        settingsStore: SettingsStore,
        locationActions: LocationActionService,
        onChange: @escaping () -> Void
    ) {
        self.focusItemId = focusItemId
        self.itineraryRepository = itineraryRepository
        self.tripRepository = tripRepository
        self.notificationService = notificationService
        self.documentRepository = documentRepository
        self.documentStorage = documentStorage
        self.settingsStore = settingsStore
        self.locationActions = locationActions
        self.onChange = onChange
        _viewModel = StateObject(
            wrappedValue: TripDetailViewModel(
                trip: trip,
                itineraryRepository: itineraryRepository,
                tripRepository: tripRepository,
                notificationService: notificationService,
                locationActions: locationActions
            )
        )
        _documentsViewModel = StateObject(
            wrappedValue: DocumentListViewModel(
                tripId: trip.id,
                repository: documentRepository,
                storage: documentStorage
            )
        )
    }

    var body: some View {
        ZStack {
            TKBackground()
            List {
                Section {
                    header
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                if !viewModel.trip.notes.isEmpty {
                    Section {
                        Text(viewModel.trip.notes)
                            .font(TKTypography.body)
                            .foregroundStyle(TKColors.textPrimary)
                    } header: {
                        Label("Notes", systemImage: "note.text")
                            .font(TKTypography.sectionHeader)
                            .foregroundStyle(TKColors.textSecondary)
                            .textCase(nil)
                    }
                }

                if let focus = viewModel.focus {
                    Section {
                        Button {
                            editingItem = focus.item
                        } label: {
                            FocusCard(focus: focus)
                        }
                        .buttonStyle(.plain)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                ItineraryTimelineView(
                    items: viewModel.items,
                    attachedItemIds: documentsViewModel.itemIdsWithAttachments,
                    onSelect: { item in editingItem = item },
                    onDelete: { item in
                        Task { await viewModel.deleteItem(item) }
                    },
                    onAddItem: { isCreatingItem = true },
                    onLocationAction: { item, action in
                        switch action {
                        case .openInMaps:
                            viewModel.openInMaps(for: item)
                        case .copyAddress:
                            viewModel.copyAddress(of: item)
                        case .copyLocationName:
                            viewModel.copyLocationName(of: item)
                        }
                    }
                )

                DocumentsSection(
                    viewModel: documentsViewModel,
                    itineraryItems: viewModel.items,
                    isPickingFile: $isPickingFile,
                    isPickingPhoto: $isPickingPhoto,
                    previewURL: $previewURL
                )
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(viewModel.trip.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isCreatingItem = true
                } label: {
                    Label("Add Item", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { isEditingTrip = true }
            }
        }
        .task {
            if viewModel.items.isEmpty {
                await viewModel.load()
            }
            if documentsViewModel.documents.isEmpty {
                await documentsViewModel.load()
            }
            consumeFocusItemIfNeeded()
        }
        .sheet(isPresented: $isEditingTrip) {
            NavigationStack {
                TripEditorView(
                    mode: .edit(viewModel.trip),
                    repository: tripRepository,
                    onSaved: {
                        Task {
                            await viewModel.refreshTrip()
                            onChange()
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $isCreatingItem) {
            NavigationStack {
                ItineraryItemEditorView(
                    mode: .create(
                        tripId: viewModel.trip.id,
                        defaultStartDate: viewModel.trip.startDate
                    ),
                    repository: itineraryRepository,
                    notificationService: notificationService,
                    locationActions: locationActions,
                    tripRange: viewModel.trip.startDate...viewModel.trip.endDate,
                    defaultReminderOption: settingsStore.defaultReminderOption(),
                    onSaved: {
                        Task { await viewModel.load() }
                    }
                )
            }
        }
        .sheet(item: $editingItem) { item in
            NavigationStack {
                ItineraryItemEditorView(
                    mode: .edit(item),
                    repository: itineraryRepository,
                    notificationService: notificationService,
                    locationActions: locationActions,
                    tripRange: viewModel.trip.startDate...viewModel.trip.endDate,
                    associatedDocuments: documentsViewModel.documents.attached(toItemId: item.id),
                    resolveDocumentURL: { documentsViewModel.absoluteURL(for: $0) },
                    onSaved: {
                        Task { await viewModel.load() }
                    }
                )
            }
        }
        .fileImporter(
            isPresented: $isPickingFile,
            allowedContentTypes: [.pdf, .image, .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    Task { await documentsViewModel.attach(from: url) }
                }
            case .failure(let error):
                let ns = error as NSError
                if !(ns.domain == NSCocoaErrorDomain && ns.code == NSUserCancelledError) {
                    documentsViewModel.errorMessage = error.localizedDescription
                }
            }
        }
        .photosPicker(
            isPresented: $isPickingPhoto,
            selection: $selectedPhoto,
            matching: .images
        )
        .onChange(of: selectedPhoto) { _, newValue in
            guard let newValue else { return }
            Task {
                if let data = try? await newValue.loadTransferable(type: Data.self) {
                    await documentsViewModel.attachPhoto(data: data, capturedAt: Date())
                } else {
                    documentsViewModel.errorMessage = "Couldn't read the selected photo."
                }
                selectedPhoto = nil
            }
        }
        .quickLookSheet(url: $previewURL)
        .errorAlert(title: "Something went wrong", message: $viewModel.errorMessage)
        .errorAlert(title: "Couldn't update document", message: $documentsViewModel.errorMessage)
    }

    // Opens the editor for the item identified by focusItemId. Fires at most
    // once per view lifetime — back-navigation that re-runs `.task` won't
    // re-present the editor if the user already dismissed it.
    private func consumeFocusItemIfNeeded() {
        guard !hasConsumedFocus, let focusItemId else { return }
        hasConsumedFocus = true
        if let match = viewModel.items.first(where: { $0.id == focusItemId }) {
            editingItem = match
        }
    }

    private var header: some View {
        let status = viewModel.trip.status()
        return VStack(alignment: .leading, spacing: TKSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: TKSpacing.xs) {
                    Image(systemName: "mappin.and.ellipse")
                        .accessibilityHidden(true)
                    Text(viewModel.trip.destination)
                }
                .font(TKTypography.heroTitle)
                .foregroundStyle(TKColors.textPrimary)
                .lineLimit(2)

                Spacer(minLength: TKSpacing.sm)
                TKBadge(text: status.displayName, color: TKColors.status(status))
            }

            HStack(spacing: TKSpacing.xs) {
                Image(systemName: "calendar")
                    .accessibilityHidden(true)
                Text(TripDateFormatter.dateRange(from: viewModel.trip.startDate, to: viewModel.trip.endDate))
            }
            .font(TKTypography.cardSubtitle)
            .foregroundStyle(TKColors.textSecondary)
        }
        .tkCard(background: TKColors.brand.opacity(0.12))
        .padding(.horizontal, TKSpacing.lg)
        .padding(.top, TKSpacing.sm)
        .padding(.bottom, TKSpacing.xs)
    }
}

// Helper that collapses the common "alert when an optional String? error message
// is non-nil, clear it on dismiss" pattern into a single modifier. Inlining two
// of these in the view body exhausted the Swift type-checker's budget.
private extension View {
    func errorAlert(title: String, message: Binding<String?>) -> some View {
        let isPresented = Binding<Bool>(
            get: { message.wrappedValue != nil },
            set: { newValue in if !newValue { message.wrappedValue = nil } }
        )
        return alert(
            title,
            isPresented: isPresented,
            presenting: message.wrappedValue
        ) { _ in
            Button("OK", role: .cancel) { message.wrappedValue = nil }
        } message: { text in
            Text(text)
        }
    }
}

private struct FocusCard: View {
    let focus: ItineraryFocus

    private var item: ItineraryItem { focus.item }

    private var label: String {
        switch focus {
        case .happeningNow: return "Happening Now"
        case .upNext: return "Up Next"
        }
    }

    private var accentColor: Color {
        switch focus {
        case .happeningNow: return TKColors.status(.active)
        case .upNext: return TKColors.brand
        }
    }

    private var cardBackground: Color {
        accentColor.opacity(0.14)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TKSpacing.sm) {
            TKBadge(text: label, color: accentColor)

            HStack(alignment: .top, spacing: TKSpacing.md) {
                Image(systemName: item.type.systemImageName)
                    .font(.title3)
                    .foregroundStyle(TKColors.itinerary(item.type))
                    .frame(width: 36, height: 36)
                    .background(
                        TKColors.itinerary(item.type).opacity(0.18),
                        in: RoundedRectangle(cornerRadius: TKRadius.small, style: .continuous)
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: TKSpacing.xs) {
                    Text(item.title)
                        .font(TKTypography.cardTitle)
                        .foregroundStyle(TKColors.textPrimary)
                        .lineLimit(2)

                    Text(TripDateFormatter.timeRange(start: item.startDate, end: item.endDate))
                        .font(TKTypography.cardSubtitle)
                        .foregroundStyle(TKColors.textSecondary)

                    if !item.locationName.isEmpty {
                        HStack(spacing: TKSpacing.xs) {
                            Image(systemName: "mappin")
                                .accessibilityHidden(true)
                            Text(item.locationName)
                        }
                        .font(TKTypography.metadata)
                        .foregroundStyle(TKColors.textSecondary)
                        .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }
        }
        .tkCard(background: cardBackground)
        .padding(.horizontal, TKSpacing.lg)
        .padding(.bottom, TKSpacing.xs)
    }
}

#if DEBUG
#Preview {
    let stack = CoreDataStack.previewSeeded()
    NavigationStack {
        TripDetailView(
            trip: MockData.tokyoTrip,
            itineraryRepository: CoreDataItineraryRepository(stack: stack),
            tripRepository: CoreDataTripRepository(stack: stack),
            notificationService: UserNotificationSchedulingService(),
            documentRepository: CoreDataDocumentRepository(stack: stack),
            documentStorage: FileManagerDocumentStorageService(),
            settingsStore: UserDefaultsSettingsStore(defaults: UserDefaults(suiteName: "TripKite-Preview")!),
            locationActions: SystemLocationActionService(),
            onChange: {}
        )
    }
}
#endif
