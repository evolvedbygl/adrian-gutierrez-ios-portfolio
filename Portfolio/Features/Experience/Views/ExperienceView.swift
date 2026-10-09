import SwiftUI

/// Career timeline, followed by the short "Before Software" story.
struct ExperienceView: View {
    let viewModel: PortfolioViewModel

    var body: some View {
        NavigationStack {
            LoadableContent(viewModel: viewModel) { portfolio in
                if portfolio.experience.isEmpty && portfolio.beforeSoftware.isEmpty {
                    EmptySectionView(
                        title: "No experience listed yet",
                        message: "Check back soon.",
                        systemImage: "briefcase"
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 40) {
                            if !portfolio.experience.isEmpty {
                                timeline(portfolio.experience)
                            }
                            if !portfolio.beforeSoftware.isEmpty {
                                beforeSoftware(portfolio.beforeSoftware)
                            }
                        }
                        .readableColumn()
                    }
                    .portfolioScreen()
                }
            }
            .navigationTitle("Experience")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private func timeline(_ items: [Experience]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                TimelineRow(experience: item, isLast: index == items.count - 1)
            }
        }
    }

    private func beforeSoftware(_ paragraphs: [String]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Before software")
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph)
                    .font(Typography.body)
                    .foregroundStyle(Color.portfolioText)
            }
        }
    }
}

#Preview("Light") {
    ExperienceView(viewModel: .preview())
}

#Preview("Dark") {
    ExperienceView(viewModel: .preview(source: .cache))
        .preferredColorScheme(.dark)
}

#Preview("Loading") {
    ExperienceView(viewModel: .previewLoading())
}

#Preview("Failed") {
    ExperienceView(viewModel: .previewFailed())
}

#Preview("Empty") {
    ExperienceView(viewModel: .preview(Portfolio(headline: "iOS Engineer", about: ["Hello"])))
}
