import SwiftUI

struct TKBadge: View {
    let text: String
    var systemImage: String?
    var color: Color = TKColors.brand

    var body: some View {
        HStack(spacing: TKSpacing.xs) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(text)
        }
        .font(TKTypography.metadataEmphasized)
        .padding(.horizontal, TKSpacing.sm)
        .padding(.vertical, TKSpacing.xs)
        // Tag-like rounded rectangle instead of a full capsule: reads as a
        // label tag (the way Apple Mail flags appear) rather than a pill,
        // and the 0.22 background opacity gives the V2.6 accent a bit more
        // presence on tinted cards.
        .background(
            color.opacity(0.22),
            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
        )
        .foregroundStyle(color)
    }
}

#if DEBUG
#Preview {
    VStack(spacing: TKSpacing.sm) {
        TKBadge(text: "Upcoming", color: .blue)
        TKBadge(text: "Active", color: .green)
        TKBadge(text: "Flight", systemImage: "airplane", color: .blue)
    }
    .padding()
}
#endif
