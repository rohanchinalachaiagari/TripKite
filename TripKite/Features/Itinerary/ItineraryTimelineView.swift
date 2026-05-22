import SwiftUI

struct ItineraryTimelineView: View {
    let items: [ItineraryItem]
    var attachedItemIds: Set<UUID> = []
    var onSelect: ((ItineraryItem) -> Void)? = nil
    var onDelete: ((ItineraryItem) -> Void)? = nil
    var onAddItem: (() -> Void)? = nil
    // Optional location quick-actions. The closure is called with the action
    // the user picked; the host view model decides how to fulfill it. When
    // nil, no Location section appears in the row context menu.
    var onLocationAction: ((ItineraryItem, LocationAction) -> Void)? = nil

    private var groupedByDay: [(day: Date, items: [ItineraryItem])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: items.sorted(by: { $0.startDate < $1.startDate })) { item in
            calendar.startOfDay(for: item.startDate)
        }
        return grouped
            .map { (day: $0.key, items: $0.value) }
            .sorted { $0.day < $1.day }
    }

    var body: some View {
        if items.isEmpty {
            Section {
                TKEmptyStateView(
                    systemImage: "calendar.badge.plus",
                    title: "No itinerary items yet",
                    message: "Add flights, hotels, and activities to build your trip timeline.",
                    actionTitle: onAddItem != nil ? "Add your first item" : nil,
                    actionSystemImage: "plus",
                    action: onAddItem
                )
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
        } else {
            ForEach(groupedByDay, id: \.day) { group in
                Section {
                    ForEach(group.items) { item in
                        row(for: item)
                    }
                } header: {
                    Text(TripDateFormatter.dayHeader(group.day))
                        .font(TKTypography.sectionHeader)
                        .foregroundStyle(TKColors.textSecondary)
                        .textCase(nil)
                }
            }
        }
    }

    @ViewBuilder
    private func row(for item: ItineraryItem) -> some View {
        let content = ItineraryItemRow(item: item, hasAttachments: attachedItemIds.contains(item.id))
        if let onSelect {
            Button {
                onSelect(item)
            } label: {
                content
            }
            .buttonStyle(.plain)
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                if let onDelete {
                    Button(role: .destructive) {
                        onDelete(item)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .contextMenu {
                locationContextMenu(for: item)
            }
        } else {
            content
        }
    }

    @ViewBuilder
    private func locationContextMenu(for item: ItineraryItem) -> some View {
        if let onLocationAction {
            let available = LocationActionAvailability.actions(
                name: item.locationName,
                address: item.address
            )
            if available.contains(.openInMaps) {
                Button {
                    onLocationAction(item, .openInMaps)
                } label: {
                    Label("Open in Maps", systemImage: "map")
                }
            }
            if available.contains(.copyAddress) {
                Button {
                    onLocationAction(item, .copyAddress)
                } label: {
                    Label("Copy Address", systemImage: "doc.on.doc")
                }
            }
            if available.contains(.copyLocationName) {
                Button {
                    onLocationAction(item, .copyLocationName)
                } label: {
                    Label("Copy Location Name", systemImage: "mappin")
                }
            }
        }
    }
}

#if DEBUG
#Preview("With items") {
    List {
        ItineraryTimelineView(items: MockData.tokyoItinerary)
    }
}

#Preview("Empty") {
    List {
        ItineraryTimelineView(items: [], onAddItem: {})
    }
}
#endif
