import SwiftUI

struct DocumentsSection: View {
    @ObservedObject var viewModel: DocumentListViewModel
    let itineraryItems: [ItineraryItem]
    @Binding var isPickingFile: Bool
    @Binding var isPickingPhoto: Bool
    @Binding var previewURL: URL?

    @State private var renamingDocument: TravelDocument?
    @State private var renameField: String = ""
    @State private var isRenaming: Bool = false

    var body: some View {
        Section {
            if viewModel.documents.isEmpty {
                emptyStateRow
            } else {
                ForEach(viewModel.documents) { document in
                    row(for: document)
                }
            }
        } header: {
            header
        }
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
    }

    private func startRename(_ document: TravelDocument) {
        renamingDocument = document
        renameField = document.fileName
        isRenaming = true
    }

    private var header: some View {
        HStack(spacing: TKSpacing.sm) {
            Label("Documents", systemImage: "doc.fill")
                .font(TKTypography.sectionHeader)
                .foregroundStyle(TKColors.textSecondary)
                .textCase(nil)
            Spacer(minLength: 0)
            addMenu {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(TKColors.brand)
            }
        }
    }

    private func row(for document: TravelDocument) -> some View {
        Button {
            previewURL = viewModel.absoluteURL(for: document)
        } label: {
            HStack(alignment: .top, spacing: TKSpacing.md) {
                Image(systemName: document.systemImageName)
                    .font(.title3)
                    .foregroundStyle(TKColors.brand)
                    .frame(width: 36, height: 36)
                    .background(
                        TKColors.brand.opacity(0.18),
                        in: RoundedRectangle(cornerRadius: TKRadius.small, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: TKSpacing.xs) {
                    Text(document.fileName)
                        .font(TKTypography.cardTitle)
                        .foregroundStyle(TKColors.textPrimary)
                        .lineLimit(2)

                    if let subtitle = subtitle(for: document) {
                        Text(subtitle)
                            .font(TKTypography.metadata)
                            .foregroundStyle(TKColors.textSecondary)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, TKSpacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
            if !itineraryItems.isEmpty {
                assignToMenu(for: document)
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

    // Compact inline empty state — sized like a single list row so it sits
    // naturally next to the rest of the trip detail sections. The whole row
    // is tappable and shows the same Files / Photos chooser the header offers.
    private var emptyStateRow: some View {
        addMenu {
            HStack(spacing: TKSpacing.md) {
                Image(systemName: "doc.badge.plus")
                    .font(.title3)
                    .foregroundStyle(TKColors.brand)
                    .frame(width: 36, height: 36)
                    .background(
                        TKColors.brand.opacity(0.18),
                        in: RoundedRectangle(cornerRadius: TKRadius.small, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: TKSpacing.xs) {
                    Text("No documents yet")
                        .font(TKTypography.cardTitle)
                        .foregroundStyle(TKColors.textPrimary)
                    Text("Attach tickets, confirmations, or screenshots.")
                        .font(TKTypography.metadata)
                        .foregroundStyle(TKColors.textSecondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, TKSpacing.xs)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Add a document")
    }

    private func addMenu<MenuLabel: View>(@ViewBuilder label: () -> MenuLabel) -> some View {
        Menu {
            Button {
                isPickingFile = true
            } label: {
                Label("Choose from Files", systemImage: "folder")
            }
            Button {
                isPickingPhoto = true
            } label: {
                Label("Choose from Photos", systemImage: "photo.on.rectangle")
            }
        } label: {
            label()
        }
    }

    private func subtitle(for document: TravelDocument) -> String? {
        let size = document.fileSize.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) }
        let type = document.fileType.isEmpty ? nil : document.fileType.uppercased()
        let itemTitle = document.itineraryItemId.flatMap { id in
            itineraryItems.first(where: { $0.id == id })?.title
        }
        let parts = [size, type, itemTitle].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    @ViewBuilder
    private func assignToMenu(for document: TravelDocument) -> some View {
        Menu {
            Button {
                Task { await viewModel.setAssociation(for: document, itineraryItemId: nil) }
            } label: {
                Label("Entire trip", systemImage: "suitcase")
            }
            Divider()
            ForEach(itineraryItems) { item in
                Button {
                    Task { await viewModel.setAssociation(for: document, itineraryItemId: item.id) }
                } label: {
                    Label(item.title, systemImage: item.type.systemImageName)
                }
            }
        } label: {
            Label("Assign to…", systemImage: "paperclip")
        }
    }
}
