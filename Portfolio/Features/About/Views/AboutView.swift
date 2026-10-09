import SwiftUI

/// Hero and About copy. Pull down to refresh content from the network.
struct AboutView: View {
    let viewModel: PortfolioViewModel

    var body: some View {
        NavigationStack {
            LoadableContent(viewModel: viewModel) { portfolio in
                if isEmpty(portfolio) {
                    EmptySectionView(
                        title: "Nothing here yet",
                        message: "Pull down to check for new content.",
                        systemImage: "person.crop.circle"
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 32) {
                            hero(portfolio)
                            if !portfolio.about.isEmpty {
                                aboutSection(portfolio.about)
                            }
                        }
                        .readableColumn()
                    }
                    .refreshable { await viewModel.refresh() }
                    .portfolioScreen()
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func isEmpty(_ portfolio: Portfolio) -> Bool {
        portfolio.name.isBlank && portfolio.headline.isBlank && portfolio.tagline.isBlank && portfolio.about.isEmpty
    }

    private func hero(_ portfolio: Portfolio) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            PortraitView(name: portfolio.name, initials: portfolio.initials)
            if !portfolio.availability.isBlank {
                AvailabilityBadge(text: portfolio.availability)
            }
            VStack(alignment: .leading, spacing: 6) {
                if !portfolio.name.isBlank {
                    Text(portfolio.name)
                        .font(Typography.display)
                        .foregroundStyle(Color.portfolioText)
                        .accessibilityAddTraits(.isHeader)
                }
                if !portfolio.headline.isBlank {
                    Text(portfolio.headline)
                        .font(Typography.headline)
                        .foregroundStyle(Color.portfolioGold)
                }
            }
            if !portfolio.tagline.isBlank {
                Text(portfolio.tagline)
                    .font(Typography.body)
                    .foregroundStyle(Color.portfolioSecondaryText)
            }
        }
    }

    private func aboutSection(_ paragraphs: [String]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "About")
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph)
                    .font(Typography.body)
                    .foregroundStyle(Color.portfolioText)
            }
        }
    }
}

#Preview("Light") {
    AboutView(viewModel: .preview())
}

#Preview("Dark, offline content") {
    AboutView(viewModel: .preview(source: .bundle))
        .preferredColorScheme(.dark)
}

#Preview("Loading") {
    AboutView(viewModel: .previewLoading())
}

#Preview("Failed") {
    AboutView(viewModel: .previewFailed())
}

#Preview("Empty") {
    AboutView(viewModel: .preview(Portfolio(about: [], contact: Contact())))
}
