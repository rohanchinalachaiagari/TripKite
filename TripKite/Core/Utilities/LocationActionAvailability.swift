import Foundation

enum LocationAction: Hashable, CaseIterable {
    case openInMaps
    case copyAddress
    case copyLocationName
}

// Decides which location quick-actions a given pair of free-text fields can
// offer. Whitespace-only is treated as blank so a stray space doesn't surface
// an action that would copy "" to the pasteboard.
enum LocationActionAvailability {
    static func actions(name: String, address: String) -> Set<LocationAction> {
        let hasName = !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasAddress = !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        var result: Set<LocationAction> = []
        if hasName || hasAddress {
            result.insert(.openInMaps)
        }
        if hasAddress {
            result.insert(.copyAddress)
        }
        if hasName {
            result.insert(.copyLocationName)
        }
        return result
    }
}
