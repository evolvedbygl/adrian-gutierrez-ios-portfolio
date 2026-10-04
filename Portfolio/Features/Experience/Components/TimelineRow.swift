import SwiftUI

/// One entry on the Experience timeline: a gold marker and rule on the leading
/// edge, details on the trailing side.
struct TimelineRow: View {
    let experience: Experience
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 0) {
                Circle()
                    .fill(Color.portfolioGold)
                    .frame(width: 12, height: 12)
                    .padding(.top, 5)
                if !isLast {
                    Rectangle()
                        .fill(Color.portfolioHairline)
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 12)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                if !experience.dateRangeText.isEmpty {
                    Text(experience.dateRangeText)
                        .font(Typography.label)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.portfolioSecondaryText)
                }
                if !experience.title.isBlank {
                    Text(experience.title)
                        .font(Typography.itemTitle)
                        .foregroundStyle(Color.portfolioText)
                        .accessibilityAddTraits(.isHeader)
                }
                if !experience.company.isBlank {
                    Text(experience.company)
                        .font(Typography.bodyEmphasis)
                        .foregroundStyle(Color.portfolioText)
                }
                if !experience.detail.isBlank {
                    Text(experience.detail)
                        .font(Typography.caption)
                        .foregroundStyle(Color.portfolioSecondaryText)
                }
                if !experience.summary.isBlank {
                    Text(experience.summary)
                        .font(Typography.body)
                        .foregroundStyle(Color.portfolioText)
                        .padding(.top, 4)
                }
                if !experience.bullets.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(experience.bullets.enumerated()), id: \.offset) { _, bullet in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text("•")
                                    .foregroundStyle(Color.portfolioGold)
                                    .accessibilityHidden(true)
                                Text(bullet)
                                    .font(Typography.body)
                                    .foregroundStyle(Color.portfolioText)
                            }
                        }
                    }
                    .padding(.top, 2)
                }
            }
            .padding(.bottom, isLast ? 0 : 28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .contain)
    }
}

#Preview("Timeline") {
    let items = Portfolio.sample.experience
    return ScrollView {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                TimelineRow(experience: item, isLast: index == items.count - 1)
            }
        }
        .readableColumn()
    }
    .portfolioScreen()
}
