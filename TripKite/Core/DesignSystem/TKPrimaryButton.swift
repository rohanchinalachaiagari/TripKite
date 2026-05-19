import SwiftUI

struct TKPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TKTypography.cardTitle)
            .foregroundStyle(.white)
            .padding(.vertical, TKSpacing.md)
            .padding(.horizontal, TKSpacing.xl)
            .frame(minWidth: 200)
            .background(
                LinearGradient(
                    colors: [
                        TKColors.brand,
                        TKColors.brand.opacity(0.82)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: Capsule()
            )
            .shadow(color: TKColors.brand.opacity(0.30), radius: 8, y: 4)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

extension ButtonStyle where Self == TKPrimaryButtonStyle {
    static var tkPrimary: TKPrimaryButtonStyle { TKPrimaryButtonStyle() }
}

#if DEBUG
#Preview {
    Button {
    } label: {
        Label("Plan your first trip", systemImage: "airplane.departure")
    }
    .buttonStyle(.tkPrimary)
    .padding()
}
#endif
