import SwiftUI

@main
struct PortfolioApp: App {
    @State private var viewModel: PortfolioViewModel

    /// Composition root: every dependency is built here and injected downward.
    init() {
        let service = LivePortfolioService(
            remoteURL: URL(string: "https://evolvedbygl.com/portfolio.json"),
            apiClient: APIClient(session: APIClient.makeSession()),
            cache: FilePortfolioCache.standard(),
            bundled: BundleContentProvider(bundle: .main)
        )
        _viewModel = State(initialValue: PortfolioViewModel(service: service))
    }

    var body: some Scene {
        WindowGroup {
            RootView(viewModel: viewModel, initialTab: Self.initialTab)
        }
    }

    /// Debug builds accept `-initialTab <about|experience|work|contact>` so a tab
    /// can be opened directly (screenshots, UI checks). Release builds always open About.
    private static var initialTab: AppTab {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let flag = arguments.firstIndex(of: "-initialTab"),
           arguments.indices.contains(flag + 1),
           let tab = AppTab(rawValue: arguments[flag + 1]) {
            return tab
        }
        #endif
        return .about
    }
}
