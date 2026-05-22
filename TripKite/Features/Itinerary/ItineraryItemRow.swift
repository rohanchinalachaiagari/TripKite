import SwiftUI

struct ItineraryItemRow: View {
    let item: ItineraryItem
    var hasAttachments: Bool = false

    private var typeColor: Color { TKColors.itinerary(item.type) }

    var body: some View {
        HStack(alignment: .top, spacing: TKSpacing.md) {
            iconTile

            VStack(alignment: .leading, spacing: TKSpacing.xs) {
                Text(item.title)
                    .font(TKTypography.cardTitle)
                    .foregroundStyle(TKColors.textPrimary)
                    .lineLimit(2)

                Text(TripDateFormatter.timeRange(start: item.startDate, end: item.endDate))
                    .font(TKTypography.cardSubtitle)
                    .foregroundStyle(TKColors.textSecondary)

                if !item.locationName.isEmpty {
                    // Manual HStack rather than `Label` because `Label`'s
                    // default icon/title spacing reads as a visible gap at
                    // metadata font sizes, making the pin feel detached from
                    // the place name.
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

            if hasAttachments {
                Image(systemName: "paperclip")
                    .font(TKTypography.metadata)
                    .foregroundStyle(TKColors.textSecondary)
                    .accessibilityLabel("Has documents")
            }
        }
        .padding(.vertical, TKSpacing.xs)
    }

    private var iconTile: some View {
        Image(systemName: item.type.systemImageName)
            .font(.title3)
            .foregroundStyle(typeColor)
            .frame(width: 36, height: 36)
            .background(typeColor.opacity(0.18), in: RoundedRectangle(cornerRadius: TKRadius.small, style: .continuous))
            .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview {
    List {
        ForEach(MockData.tokyoItinerary) { item in
            ItineraryItemRow(item: item, hasAttachments: item.type == .flight)
        }
    }
}
#endif
