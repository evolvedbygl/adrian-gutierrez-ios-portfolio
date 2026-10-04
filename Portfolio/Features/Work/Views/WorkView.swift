import SwiftUI

/// Selected work (the three apps) and capabilities.
struct WorkView: View {
    let viewModel: PortfolioViewModel
    @State private var webDestination: WebDestination?

    var body: some View {
        NavigationStack {
            LoadableContent(viewModel: viewModel) { portfolio in
                if portfolio.projects.isEmpty && portfolio.capabilityGroups.isEmpty {
                    EmptySectionView(
                        title: "No work listed yet",
                        message: "Check back soon.",
                        systemImage: "square.stack.3d.up"
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 40) {
                            if !portfolio.projects.isEmpty {
                                projects(portfolio.projects)
                            }
                            if !portfolio.capabilityGroups.isEmpty {
                                capabilities(portfolio.capabilityGroups)
                            }
                        }
                        .readableColumn()
                    }
                    .portfolioScreen()
                }
            }
            .navigationTitle("Work")
            .navigationBarTitleDisplayMode(.large)
            .offlineIndicator(viewModel.isShowingOfflineContent)
            .safariSheet(item: $webDestination)
        }
    }

    private func projects(_ projects: [Project]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Selected work")
            ForEach(Array(projects.enumerated()), id: \.offset) { _, project in
                ProjectCard(project: project) { url in
                    webDestination = WebDestination(url: url)
                }
            }
        }
    }

    private func capabilities(_ groups: [CapabilityGroup]) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionHeader(title: "Capabilities")
            ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                CapabilityGroupView(group: group)
            }
        }
    }
}

#Preview("Light") {
    WorkView(viewModel: .preview())
}

#Preview("Dark") {
    WorkView(viewModel: .preview())
        .preferredColorScheme(.dark)
}

#Preview("Loading") {
    WorkView(viewModel: .previewLoading())
}

#Preview("Failed") {
    WorkView(viewModel: .previewFailed())
}

#Preview("Empty") {
    WorkView(viewModel: .preview(Portfolio(headline: "iOS Engineer", about: ["Hello"])))
}
