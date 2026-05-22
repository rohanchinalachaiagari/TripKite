import SwiftUI

// Standalone Privacy screen pushed from Settings. Keeps the privacy summary
// out of the Settings root so the section list stays scannable, and gives
// reviewers a clean self-contained surface to read.
struct PrivacyView: View {
    var body: some View {
        ZStack {
            TKBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: TKSpacing.lg) {
                    Text("TripKite stores your trips, itinerary items, reminders, and documents locally on this device.")
                        .font(TKTypography.body)
                        .foregroundStyle(TKColors.textPrimary)

                    Text("There is no account, no analytics, and no server. TripKite does not send your personal travel data anywhere.")
                        .font(TKTypography.body)
                        .foregroundStyle(TKColors.textPrimary)

                    Text("Documents you attach are stored in TripKite's sandbox on this device. They may be included in your standard iOS device backup if you have iCloud Backup enabled.")
                        .font(TKTypography.body)
                        .foregroundStyle(TKColors.textPrimary)

                    Text("Opening an itinerary location in Apple Maps hands the address or location name to the Maps app. TripKite does not request or store your current location.")
                        .font(TKTypography.body)
                        .foregroundStyle(TKColors.textPrimary)
                }
                .padding(.horizontal, TKSpacing.lg)
                .padding(.vertical, TKSpacing.xl)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        PrivacyView()
    }
}
#endif
