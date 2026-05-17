import SwiftUI

struct ItineraryItemRow: View {
    let item: ItineraryItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.type.systemImageName)
                .font(.title3)
                .frame(width: 32, height: 32)
                .foregroundStyle(.white)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(2)

                Text(TripDateFormatter.timeRange(start: item.startDate, end: item.endDate))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if !item.locationName.isEmpty {
                    Label(item.locationName, systemImage: "mappin")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    List {
        ForEach(MockData.tokyoItinerary) { item in
            ItineraryItemRow(item: item)
        }
    }
}
