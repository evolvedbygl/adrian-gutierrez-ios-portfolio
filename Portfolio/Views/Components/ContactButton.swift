import SwiftUI

/// The visual treatment shared by every row on the Contact tab (buttons and the share link).
struct ContactRowLabel: View {
    let title: String
    let detail: String?
    let systemImage: String
    var trailingImage: String = "chevron.right"

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(Color.portfolioGold)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typography.button)
                    .foregroundStyle(Color.portfolioText)
                if let detail, !detail.isBlank {
                    Text(detail)
                        .font(Typography.caption)
                        .foregroundStyle(Color.portfolioSecondaryText)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            Image(systemName: trailingImage)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.portfolioSecondaryText)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.portfolioSurface))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.portfolioHairline, lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// Dims slightly while pressed.
struct PressableRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.65 : 1)
    }
}

struct ContactButton: View {
    let title: String
    let detail: String?
    let systemImage: String
    var trailingImage: String = "chevron.right"
    let accessibilityHint: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ContactRowLabel(title: title, detail: detail, systemImage: systemImage, trailingImage: trailingImage)
        }
        .buttonStyle(PressableRowStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(detail.map { "\(title), \($0)" } ?? title)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(.isButton)
    }
}

#Preview("Contact button") {
    VStack(spacing: 12) {
        ContactButton(
            title: "Email", detail: "name@example.com", systemImage: "envelope",
            accessibilityHint: "Opens Mail", action: {}
        )
        ContactButton(
            title: "LinkedIn", detail: "linkedin.com/in/name", systemImage: "link",
            trailingImage: "arrow.up.right", accessibilityHint: "Opens in an in-app browser", action: {}
        )
    }
    .padding()
    .portfolioScreen()
}
