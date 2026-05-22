import Foundation
#if canImport(UIKit)
import UIKit
#endif

// Thin wrapper around the UIKit side effects required for V2.5 location
// quick-actions. ViewModels depend on this protocol so they can stay free of
// UIKit imports, and tests can substitute a recording mock.
//
// Methods are MainActor-isolated because UIApplication / UIPasteboard are
// main-thread APIs. The protocol itself is non-isolated so concrete types can
// be instantiated from any context (e.g., during App.init).
protocol LocationActionService: AnyObject, Sendable {
    @MainActor func openInMaps(name: String, address: String)
    @MainActor func copy(text: String)
}

#if canImport(UIKit)
final class SystemLocationActionService: LocationActionService, @unchecked Sendable {
    @MainActor
    func openInMaps(name: String, address: String) {
        guard let url = AppleMapsURL.searchURL(name: name, address: address) else {
            return
        }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    @MainActor
    func copy(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        UIPasteboard.general.string = trimmed
    }
}
#endif
