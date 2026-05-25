import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct DocumentVaultView: View {
    @StateObject private var viewModel: DocumentVaultViewModel

    @State private var renamingDocument: TravelDocument?
    @State private var renameField: String = ""
    @State private var isRenaming: Bool = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var previewURL: URL?

    init(
        documentRepository: DocumentRepository,
        tripRepository: TripRepository,
        itineraryRepository: ItineraryRepository,
        documentStorage: DocumentStorageService
    ) {
        _viewModel = StateObject(
            wrappedValue: DocumentVaultViewModel(
                documentRepository: documentRepository,
                tripRepository: tripRepository,
                itineraryRepository: itineraryRepository,
                storage: documentStorage
            )
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                TKBackground()
                content
            }
            .navigationTitle("Documents")
            .toolbar {
                if !viewModel.trips.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        addMenu {
                            Label("Add Document", systemImage: "plus")
                        }
                    }
                }
            }
            .task {
                // Reload every time the tab appears. Trip / document state can
                // change while the user is on another tab (a trip delete from
                // the Trips tab cascades documents here), so the vault has to
                // re-pull on return to avoid showing stale rows that point at
                // files the cascade already removed.
                await viewModel.load()
            }
            .refreshable {
                await viewModel.load()
            }
            .fileImporter(
                isPresented: $viewModel.isPickingFile,
                allowedContentTypes: [.pdf, .image, .data],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first { viewModel.stageFile(at: url) }
                case .failure(let error):
                    // User-initiated cancel surfaces as NSCocoaErrorDomain
                    // userCancelled; treat that as a silent no-op. Anything
                    // else feeds into the standard error alert.
                    let ns = error as NSError
                    if !(ns.domain == NSCocoaErrorDomain && ns.code == NSUserCancelledError) {
                        viewModel.errorMessage = error.localizedDescription
                    }
                }
            }
            .photosPicker(
                isPresented: $viewModel.isPickingPhoto,
                selection: $selectedPhoto,
                matching: .images
            )
            .onChange(of: selectedPhoto) { _, newValue in
                guard let newValue else { return }
                Task {
                    if let data = try? await newValue.loadTransferable(type: Data.self) {
                        viewModel.stagePhoto(data: data, capturedAt: Date())
                    } else {
                        viewModel.errorMessage = "Couldn't read the selected photo."
                    }
                    selectedPhoto = nil
                }
            }
            .sheet(
                item: $viewModel.pendingImport,
                onDismiss: {
                    // Sheet swiped away with the staged file still pending → treat as cancel.
                    if viewModel.pendingImport != nil {
                        viewModel.cancelImport()
                    }
                }
            ) { _ in
                DocumentImportSheet(
                    trips: viewModel.trips,
                    itemsByTripId: viewModel.itemsByTripId,
                    isAttaching: viewModel.isAttaching,
                    onConfirm: { tripId, itemId in
                        Task { await viewModel.confirmImport(tripId: tripId, itemId: itemId) }
                    },
                    onCancel: {
                        viewModel.cancelImport()
                    }
                )
            }
            .quickLookSheet(url: $previewURL)
            .alert("Rename document", isPresented: $isRenaming) {
                TextField("Name", text: $renameField)
                    .textInputAutocapitalization(.sentences)
                Button("Cancel", role: .cancel) {
                    renamingDocument = nil
                }
                Button("Save") {
                    if let document = renamingDocument {
                        let newName = renameField
                        Task { await viewModel.renameDocument(document, to: newName) }
                    }
                    renamingDocument = nil
                }
            } message: {
                Text("Enter a new name for this document.")
            }
            .alert(
                "Something went wrong",
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

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.documents.isEmpty && viewModel.trips.isEmpty {
            ProgressView()
        } else if viewModel.documents.isEmpty {
            emptyState
        } else {
            documentList
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if viewModel.trips.isEmpty {
            TKEmptyStateView(
                systemImage: "doc.on.doc.fill",
                title: "No trips yet",
                message: "Documents belong to a trip. Create a trip from the Trips tab to start attaching files.",
                style: .roundedSquare
            )
        } else {
            TKEmptyStateView(
                systemImage: "doc.on.doc.fill",
                title: "No documents yet",
                message: "Tap the plus button to attach a PDF, photo, or screenshot to one of your trips.",
                style: .roundedSquare
            )
        }
    }

    private var documentList: some View {
        List {
            ForEach(viewModel.groupedDocuments, id: \.trip.id) { group in
                Section {
                    ForEach(group.documents) { document in
                        row(for: document, in: group.trip)
                    }
                } header: {
                    Text(group.trip.title)
                        .font(TKTypography.sectionHeader)
                        .foregroundStyle(TKColors.textSecondary)
                        .textCase(nil)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private func row(for document: TravelDocument, in trip: Trip) -> some View {
        let itemTitle: String? = document.itineraryItemId.flatMap { id in
            viewModel.itemsByTripId[trip.id]?.first(where: { $0.id == id })?.title
        }
        return DocumentRowView(
            document: document,
            subtitle: DocumentRowSubtitle.make(for: document, itineraryItemTitle: itemTitle),
            onTap: { previewURL = viewModel.absoluteURL(for: document) }
        )
        .contextMenu {
            Button {
                previewURL = viewModel.absoluteURL(for: document)
            } label: {
                Label("Preview", systemImage: "eye")
            }
            Button {
                startRename(document)
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            if let items = viewModel.itemsByTripId[trip.id], !items.isEmpty {
                assignToMenu(for: document, in: trip)
            }
            Button(role: .destructive) {
                Task { await viewModel.delete(document) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                Task { await viewModel.delete(document) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func startRename(_ document: TravelDocument) {
        renamingDocument = document
        renameField = document.fileName
        isRenaming = true
    }

    @ViewBuilder
    private func assignToMenu(for document: TravelDocument, in trip: Trip) -> some View {
        Menu {
            Button {
                Task { await viewModel.setAssociation(for: document, itineraryItemId: nil) }
            } label: {
                Label("Entire trip", systemImage: "suitcase")
            }
            Divider()
            if let items = viewModel.itemsByTripId[trip.id] {
                ForEach(items) { item in
                    Button {
                        Task { await viewModel.setAssociation(for: document, itineraryItemId: item.id) }
                    } label: {
                        Label(item.title, systemImage: item.type.systemImageName)
                    }
                }
            }
        } label: {
            Label("Assign to…", systemImage: "paperclip")
        }
    }

    private func addMenu<MenuLabel: View>(@ViewBuilder label: () -> MenuLabel) -> some View {
        Menu {
            Button {
                viewModel.isPickingFile = true
            } label: {
                Label("Choose from Files", systemImage: "folder")
            }
            Button {
                viewModel.isPickingPhoto = true
            } label: {
                Label("Choose from Photos", systemImage: "photo.on.rectangle")
            }
        } label: {
            label()
        }
    }
}

#if DEBUG
#Preview("Seeded") {
    let stack = CoreDataStack.previewSeeded()
    DocumentVaultView(
        documentRepository: CoreDataDocumentRepository(stack: stack),
        tripRepository: CoreDataTripRepository(stack: stack),
        itineraryRepository: CoreDataItineraryRepository(stack: stack),
        documentStorage: FileManagerDocumentStorageService()
    )
}

#Preview("Empty") {
    let stack = CoreDataStack(inMemory: true)
    DocumentVaultView(
        documentRepository: CoreDataDocumentRepository(stack: stack),
        tripRepository: CoreDataTripRepository(stack: stack),
        itineraryRepository: CoreDataItineraryRepository(stack: stack),
        documentStorage: FileManagerDocumentStorageService()
    )
}
#endif
