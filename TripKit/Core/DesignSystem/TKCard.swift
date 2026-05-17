import SwiftUI

struct TKCardStyle: ViewModifier {
    var padding: CGFloat = TKSpacing.lg
    var cornerRadius: CGFloat = TKRadius.medium
    var background: Color = TKColors.surfaceElevated

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

extension View {
    func tkCard(
        padding: CGFloat = TKSpacing.lg,
        cornerRadius: CGFloat = TKRadius.medium,
        background: Color = TKColors.surfaceElevated
    ) -> some View {
        modifier(TKCardStyle(padding: padding, cornerRadius: cornerRadius, background: background))
    }
}
