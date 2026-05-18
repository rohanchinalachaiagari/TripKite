import Foundation

extension Sequence where Element == TravelDocument {
    // Returns documents associated with the given itinerary item. Documents
    // that belong to other items, or that are trip-level only (no itemId),
    // are filtered out. Original ordering is preserved.
    func attached(toItemId itemId: UUID) -> [TravelDocument] {
        filter { $0.itineraryItemId == itemId }
    }
}
