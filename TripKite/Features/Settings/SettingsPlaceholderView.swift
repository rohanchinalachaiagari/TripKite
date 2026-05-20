import SwiftUI

// V2.1 placeholder. V2.2 will introduce a `SettingsStore` protocol and the
// actual controls: default reminder offset, notification authorization status
// with an "Open Settings" deep link, privacy and support information, and
// local data management.
struct SettingsPlaceholderView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                TKBackground()
                TKEmptyStateView(
                    systemImage: "gearshape.fill",
                    title: "Defaults and data",
                    message: "Default reminder offsets, notification status, privacy details, and local data management will live here."
                )
            }
            .navigationTitle("Settings")
        }
    }
}

#if DEBUG
#Preview {
    SettingsPlaceholderView()
}
#endif
