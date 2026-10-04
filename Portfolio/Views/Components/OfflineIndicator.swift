import SwiftUI

/// A small "offline content" pill in the navigation bar, shown only while the
/// screen is displaying cached or bundled fallback data. Informational, never an error.
struct OfflineIndicatorModifier: ViewModifier {
    let isVisible: Bool

    func body(content: Content) -> some View {
        content.toolbar {
            if isVisible {
                ToolbarItem(placement: .topBarTrailing) {
                    Label("Offline content", systemImage: "icloud.slash")
                        .labelStyle(.titleAndIcon)
                        .font(Typography.label)
                        .foregroundStyle(Color.portfolioSecondaryText)
                        .accessibilityLabel("Showing offline content")
                }
            }
        }
    }
}

extension View {
    func offlineIndicator(_ isVisible: Bool) -> some View {
        modifier(OfflineIndicatorModifier(isVisible: isVisible))
    }
}
