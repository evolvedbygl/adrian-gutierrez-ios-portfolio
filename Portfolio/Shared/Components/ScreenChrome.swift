import SwiftUI

/// Common screen chrome: themed background and a readable column width that keeps
/// iPad (and large phones in landscape) from stretching text edge to edge.
struct PortfolioScreenModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.portfolioBackground.ignoresSafeArea())
            .foregroundStyle(Color.portfolioText)
    }
}

struct ReadableColumnModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: 680, alignment: .leading)
            .frame(maxWidth: .infinity)
    }
}

extension View {
    /// Themed background and foreground for a top-level screen.
    func portfolioScreen() -> some View { modifier(PortfolioScreenModifier()) }

    /// Constrains scroll content to a comfortable reading width with page margins.
    func readableColumn() -> some View { modifier(ReadableColumnModifier()) }
}
