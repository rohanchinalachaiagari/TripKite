import SwiftUI

struct TKBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                TKColors.brand.opacity(0.22),
                TKColors.brand.opacity(0.06),
                Color(.systemBackground)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

#if DEBUG
#Preview {
    TKBackground()
}
#endif
