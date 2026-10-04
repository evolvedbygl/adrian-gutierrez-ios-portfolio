import SwiftUI

/// "Open to iOS roles" pill.
struct AvailabilityBadge: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.portfolioGold)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text(text)
                .font(Typography.label)
                .foregroundStyle(Color.portfolioText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Capsule().fill(Color.portfolioSurface))
        .overlay(Capsule().strokeBorder(Color.portfolioHairline, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Availability: \(text)")
    }
}

#Preview("Badge") {
    AvailabilityBadge(text: "Open to iOS roles")
        .padding()
        .portfolioScreen()
}
