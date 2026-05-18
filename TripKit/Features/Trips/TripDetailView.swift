import SwiftUI
import UniformTypeIdentifiers
import PhotosUI

struct TripDetailView: View {
    @StateObject private var viewModel: TripDetailViewModel
    @StateObject private var documentsViewModel: DocumentListViewModel
    private let itineraryRepository: ItineraryRepository
    private let tripRepository: TripRepository
    private let notificationService: NotificationSchedulingService
    private let documentRepository: DocumentRepository
    private let documentStorage: DocumentStorageService
    private let onChange: () -> Void

    @State private var isEditingTrip = false
    @State private var isCreatingItem = false
    @State private var editingItem: ItineraryItem?
    @State private var isPickingFile = false
    @State private var isPickingPhoto = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var previewURL: URL?

    init(
        trip: Trip,
        itineraryRepository: ItineraryRepository,
        tripRepository: TripRepository,
        notificationService: NotificationSchedulingService,
        documentRepository: DocumentRepository,
        documentStorage: DocumentStorageService,
        onChange: @escaping () -> Void
    ) {
        self.itineraryRepository = itineraryRepository
        self.tripRepository = tripRepository
        self.notificationService = notificationService
        self.documentRepository = documentRepository
        self.documentStorage = documentStorage
        self.onChange = onChange
        _viewModel = StateObject(
            wrappedValue: TripDetailViewModel(
                trip: trip,
                itineraryRepository: itineraryRepository,
                tripRepository: tripRepository,
                notificationService: notificationService
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
                    onSelect: { item in editingItem = item },
                    onDelete: { item in
                        Task { await viewModel.deleteItem(item) }
                    },
                    onAddItem: { isCreatingItem = true }
                )

                DocumentsSection(
                    viewModel: documentsViewModel,
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
                    tripRange: viewModel.trip.startDate...viewModel.trip.endDate,
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
                    tripRange: viewModel.trip.startDate...viewModel.trip.endDate,
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
            if case .success(let urls) = result, let url = urls.first {
                Task { await documentsViewModel.attach(from: url) }
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

    private var header: some View {
        let status = viewModel.trip.status()
        return VStack(alignment: .leading, spacing: TKSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Label(viewModel.trip.destination, systemImage: "mappin.and.ellipse")
                    .font(TKTypography.heroTitle)
                    .foregroundStyle(TKColors.textPrimary)
                    .lineLimit(2)
                Spacer(minLength: TKSpacing.sm)
                TKBadge(text: status.displayName, color: TKColors.status(status))
            }

            Label(
                TripDateFormatter.dateRange(from: viewModel.trip.startDate, to: viewModel.trip.endDate),
                systemImage: "calendar"
            )
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

                VStack(alignment: .leading, spacing: TKSpacing.xs) {
                    Text(item.title)
                        .font(TKTypography.cardTitle)
                        .foregroundStyle(TKColors.textPrimary)
                        .lineLimit(2)

                    Text(TripDateFormatter.timeRange(start: item.startDate, end: item.endDate))
                        .font(TKTypography.cardSubtitle)
                        .foregroundStyle(TKColors.textSecondary)

                    if !item.locationName.isEmpty {
                        Label(item.locationName, systemImage: "mappin")
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
            onChange: {}
        )
    }
}
#endif
