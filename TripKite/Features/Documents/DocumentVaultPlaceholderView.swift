import SwiftUI

// V2.1 placeholder for the global documents tab. Distinct from the per-trip
// `DocumentsSection` already in this folder — that one shows documents within
// a single trip. This screen will surface every TravelDocument across every
// trip when V2.3 lands.
struct DocumentVaultPlaceholderView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                TKBackground()
                TKEmptyStateView(
                    systemImage: "doc.on.doc.fill",
                    title: "All your travel documents",
                    message: "A vault that gathers every PDF, ticket, and screenshot attached to any trip in one place."
                )
            }
            .navigationTitle("Documents")
        }
    }
}

#if DEBUG
#Preview {
    DocumentVaultPlaceholderView()
}
#endif
