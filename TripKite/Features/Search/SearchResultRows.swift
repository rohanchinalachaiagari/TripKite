import SwiftUI

// Trip row used in Search results. Visually echoes TripRow in TripListView but
// kept local so changes to the trips tab don't ripple here.
struct TripResultRow: View {
    let trip: Trip
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: TKSpacing.md) {
                VStack(alignment: .leading, spacing: TKSpacing.xs) {
                    Text(trip.title)
                        .font(TKTypography.cardTitle)
                        .foregroundStyle(TKColors.textPrimary)
                        .lineLimit(2)

                    HStack(spacing: TKSpacing.xs) {
                        Image(systemName: "mappin.and.ellipse")
                            .accessibilityHidden(true)
                        Text(trip.destination)
                    }
                    .font(TKTypography.cardSubtitle)
                    .foregroundStyle(TKColors.textSecondary)
                    .lineLimit(1)

                    HStack(spacing: TKSpacing.sm) {
                        Text(TripDateFormatter.dateRange(from: trip.startDate, to: trip.endDate))
                            .font(TKTypography.metadata)
                            .foregroundStyle(TKColors.textSecondary)

                        TKBadge(text: trip.status().displayName, color: TKColors.status(trip.status()))
                    }
                    .padding(.top, TKSpacing.xs)
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, TKSpacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct ItineraryResultRow: View {
    let item: ItineraryItem
    let parentTrip: Trip?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
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

                    if let subtitle {
                        Text(subtitle)
                            .font(TKTypography.metadata)
                            .foregroundStyle(TKColors.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, TKSpacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var subtitle: String? {
        let date = TripDateFormatter.mediumDate(item.startDate)
        let parts: [String] = [
            item.type.displayName,
            date,
            parentTrip?.title
        ].compactMap { value in
            guard let value, !value.isEmpty else { return nil }
            return value
        }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }
}

// Subtitle for document rows shown in Search. Adds the parent trip title to
// the existing fileSize/fileType formatting so the user can tell which trip a
// matching document belongs to.
enum SearchDocumentSubtitle {
    static func make(for document: TravelDocument, parentTripTitle: String?) -> String? {
        let size = document.fileSize.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) }
        let type = document.fileType.isEmpty ? nil : document.fileType.uppercased()
        let parts = [size, type, parentTripTitle].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }
}
