import SwiftUI

/// The four-tab shell. Also routes `portfolio://<tab>` deep links.
struct RootView: View {
    let viewModel: PortfolioViewModel
    @State private var selection: AppTab

    init(viewModel: PortfolioViewModel, initialTab: AppTab = .about) {
        self.viewModel = viewModel
        _selection = State(initialValue: initialTab)
    }

    var body: some View {
        TabView(selection: $selection) {
            AboutView(viewModel: viewModel)
                .tabItem { Label("About", systemImage: "person.crop.circle") }
                .tag(AppTab.about)
            ExperienceView(viewModel: viewModel)
                .tabItem { Label("Experience", systemImage: "briefcase") }
                .tag(AppTab.experience)
            WorkView(viewModel: viewModel)
                .tabItem { Label("Work", systemImage: "square.stack.3d.up") }
                .tag(AppTab.work)
            ContactView(viewModel: viewModel)
                .tabItem { Label("Contact", systemImage: "envelope") }
                .tag(AppTab.contact)
        }
        .tint(Color.portfolioGold)
        .task { await viewModel.start() }
        .onOpenURL { url in
            if let tab = AppTab(deepLink: url) {
                selection = tab
            }
        }
    }
}

#Preview("Root") {
    RootView(viewModel: .preview())
}

#Preview("Root, dark") {
    RootView(viewModel: .preview(source: .bundle))
        .preferredColorScheme(.dark)
}
