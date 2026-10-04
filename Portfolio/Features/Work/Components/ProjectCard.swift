import SwiftUI

/// A card for one project: name, release status, description, and outbound link.
struct ProjectCard: View {
    let project: Project
    /// Called with the validated URL when the link is tapped.
    let onOpenLink: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(project.name)
                    .font(Typography.itemTitle)
                    .foregroundStyle(Color.portfolioText)
                    .accessibilityAddTraits(.isHeader)
                if !project.status.isBlank {
                    Text(project.status)
                        .font(Typography.label)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.portfolioSecondaryText)
                }
            }

            if !project.description.isBlank {
                Text(project.description)
                    .font(Typography.body)
                    .foregroundStyle(Color.portfolioText)
            }

            if let link = project.link {
                Button {
                    onOpenLink(link)
                } label: {
                    Label(
                        project.linkLabel.isBlank ? "Learn more" : project.linkLabel,
                        systemImage: "arrow.up.right"
                    )
                    .font(Typography.button)
                    .foregroundStyle(Color.portfolioText)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .overlay(Capsule().strokeBorder(Color.portfolioGold, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(project.linkLabel.isBlank ? "Learn more" : project.linkLabel) about \(project.name)")
                .accessibilityHint("Opens in an in-app browser")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.portfolioSurface))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.portfolioHairline, lineWidth: 1))
        .accessibilityElement(children: .contain)
    }
}

#Preview("Project card") {
    ProjectCard(project: Portfolio.sample.projects.first ?? Project(name: "Sample"), onOpenLink: { _ in })
        .padding()
        .portfolioScreen()
}
