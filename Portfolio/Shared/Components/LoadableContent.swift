import SwiftUI

/// Renders the view model's loading and error states, and hands the loaded
/// portfolio to `content`. Every tab goes through this, so no screen can be blank.
struct LoadableContent<Content: View>: View {
    let viewModel: PortfolioViewModel
    @ViewBuilder let content: (Portfolio) -> Content

    var body: some View {
        switch viewModel.state {
        case .loading:
            ProgressView {
                Text("Loading…")
                    .font(Typography.caption)
                    .foregroundStyle(Color.portfolioSecondaryText)
            }
            .tint(Color.portfolioGold)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .portfolioScreen()
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Loading")

        case let .failed(error):
            ContentUnavailableView {
                Label("Content unavailable", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error.userMessage)
            } actions: {
                Button("Try Again") {
                    Task { await viewModel.retry() }
                }
                .buttonStyle(.bordered)
                .tint(Color.portfolioGold)
                .accessibilityHint("Reloads the portfolio")
            }
            .portfolioScreen()

        case let .loaded(loaded):
            content(loaded.portfolio)
        }
    }
}

/// Shown when a tab's data decoded fine but this part of it is empty.
struct EmptySectionView: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .portfolioScreen()
    }
}

#Preview("Loading") {
    LoadableContent(viewModel: .previewLoading()) { _ in Text("Loaded") }
}

#Preview("Failed") {
    LoadableContent(viewModel: .previewFailed()) { _ in Text("Loaded") }
}

#Preview("Empty") {
    EmptySectionView(
        title: "Nothing here yet",
        message: "Check back soon.",
        systemImage: "tray"
    )
}
