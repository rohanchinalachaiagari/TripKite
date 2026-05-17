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
        .background(color.opacity(0.18), in: Capsule())
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
