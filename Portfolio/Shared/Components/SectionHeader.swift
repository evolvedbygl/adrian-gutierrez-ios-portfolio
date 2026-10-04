import SwiftUI

/// A section title with a short gold rule above it.
struct SectionHeader: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Rectangle()
                .fill(Color.portfolioGold)
                .frame(width: 36, height: 2)
                .accessibilityHidden(true)
            Text(title)
                .font(Typography.sectionTitle)
                .foregroundStyle(Color.portfolioText)
                .accessibilityAddTraits(.isHeader)
        }
    }
}

#Preview("Section header") {
    SectionHeader(title: "Selected work")
        .padding()
        .portfolioScreen()
}
