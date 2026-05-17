import SwiftUI

struct TKEmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var actionSystemImage: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: TKSpacing.lg) {
            iconBackdrop

            VStack(spacing: TKSpacing.sm) {
                Text(title)
                    .font(TKTypography.heroTitle)
                    .foregroundStyle(TKColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(TKTypography.cardSubtitle)
                    .foregroundStyle(TKColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, TKSpacing.lg)

            if let actionTitle, let action {
                Button(action: action) {
                    if let actionSystemImage {
                        Label(actionTitle, systemImage: actionSystemImage)
                    } else {
                        Text(actionTitle)
                    }
                }
                .buttonStyle(.tkPrimary)
                .padding(.top, TKSpacing.xs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, TKSpacing.xxl)
        .padding(.horizontal, TKSpacing.lg)
    }

    private var iconBackdrop: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            TKColors.brand.opacity(0.28),
                            TKColors.brand.opacity(0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 112, height: 112)

            Image(systemName: systemImage)
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(TKColors.brand)
        }
    }
}

#if DEBUG
#Preview("With CTA") {
    TKEmptyStateView(
        systemImage: "suitcase",
        title: "No trips yet",
        message: "Start planning your next adventure. Add flights, hotels, and activities all in one place.",
        actionTitle: "Plan your first trip",
        actionSystemImage: "airplane.departure",
        action: {}
    )
}

#Preview("No CTA") {
    TKEmptyStateView(
        systemImage: "calendar.badge.plus",
        title: "No itinerary items yet",
        message: "Add flights, hotels, and activities to build your trip timeline."
    )
}
#endif
