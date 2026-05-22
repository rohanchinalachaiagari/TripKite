import SwiftUI

// Shared presentational row for a TravelDocument. The trip-level documents
// list and the per-item documents list both render the same icon tile, file
// name, and metadata subtitle; only their tap action and surrounding
// context-menu / swipe-action modifiers differ. Those stay at the call site.
struct DocumentRowView: View {
    let document: TravelDocument
    let subtitle: String?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: TKSpacing.md) {
                Image(systemName: document.systemImageName)
                    .font(.title3)
                    .foregroundStyle(TKColors.brand)
                    .frame(width: 36, height: 36)
                    .background(
                        TKColors.brand.opacity(0.18),
                        in: RoundedRectangle(cornerRadius: TKRadius.small, style: .continuous)
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: TKSpacing.xs) {
                    Text(document.fileName)
                        .font(TKTypography.cardTitle)
                        .foregroundStyle(TKColors.textPrimary)
                        .lineLimit(2)

                    if let subtitle {
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
    }
}

// Formats the metadata line for a TravelDocument. Used by both the trip-level
// documents list (which may also append the associated itinerary item's
// title) and the per-item documents list (which never does).
enum DocumentRowSubtitle {
    static func make(for document: TravelDocument, itineraryItemTitle: String? = nil) -> String? {
        let size = document.fileSize.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) }
        let type = document.fileType.isEmpty ? nil : document.fileType.uppercased()
        let parts = [size, type, itineraryItemTitle].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }
}

#if DEBUG
#Preview {
    List {
        DocumentRowView(
            document: TravelDocument(
                tripId: UUID(),
                fileName: "Boarding pass",
                localRelativePath: "Attachments/abc.pdf",
                fileType: "pdf",
                fileSize: 524_288
            ),
            subtitle: "512 KB • PDF",
            onTap: {}
        )
        DocumentRowView(
            document: TravelDocument(
                tripId: UUID(),
                fileName: "Screenshot-2026-05-17",
                localRelativePath: "Attachments/def.png",
                fileType: "png",
                fileSize: 1_200_000
            ),
            subtitle: "1.2 MB • PNG • ANA NH 7 SFO → HND",
            onTap: {}
        )
    }
}
#endif
