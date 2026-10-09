import SwiftUI

/// Mail, call, LinkedIn, GitHub, and the share sheet.
struct ContactView: View {
    let viewModel: PortfolioViewModel
    @State private var model = ContactViewModel()
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            LoadableContent(viewModel: viewModel) { portfolio in
                if !portfolio.contact.hasAnyAction
                    && portfolio.contact.message.isBlank
                    && portfolio.contact.websiteURL == nil {
                    EmptySectionView(
                        title: "No contact details yet",
                        message: "Check back soon.",
                        systemImage: "envelope"
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 28) {
                            intro(portfolio.contact)
                            actions(portfolio)
                        }
                        .readableColumn()
                    }
                    .portfolioScreen()
                }
            }
            .navigationTitle("Contact")
            .navigationBarTitleDisplayMode(.large)
            .safariSheet(item: $model.webDestination)
            .alert(
                "Can't Open",
                isPresented: Binding(
                    get: { model.alertMessage != nil },
                    set: { if !$0 { model.dismissAlert() } }
                ),
                actions: { Button("OK", role: .cancel) {} },
                message: { Text(model.alertMessage ?? "") }
            )
        }
    }

    // MARK: Sections

    @ViewBuilder
    private func intro(_ contact: Contact) -> some View {
        if !contact.message.isBlank || !contact.location.isBlank {
            VStack(alignment: .leading, spacing: 12) {
                if !contact.message.isBlank {
                    Text(contact.message)
                        .font(Typography.body)
                        .foregroundStyle(Color.portfolioText)
                }
                if !contact.location.isBlank {
                    Label(contact.location, systemImage: "mappin.and.ellipse")
                        .font(Typography.caption)
                        .foregroundStyle(Color.portfolioSecondaryText)
                }
            }
        }
    }

    private func actions(_ portfolio: Portfolio) -> some View {
        let contact = portfolio.contact
        return VStack(spacing: 12) {
            if contact.mailURL != nil {
                ContactButton(
                    title: "Email", detail: contact.email, systemImage: "envelope",
                    accessibilityHint: "Opens Mail"
                ) { perform(.email, contact) }
            }
            if contact.phoneURL != nil {
                ContactButton(
                    title: "Call", detail: contact.phone, systemImage: "phone",
                    accessibilityHint: "Starts a phone call"
                ) { perform(.call, contact) }
            }
            if let linkedIn = contact.linkedInURL {
                ContactButton(
                    title: "LinkedIn", detail: linkedIn.displayString, systemImage: "person.2",
                    trailingImage: "arrow.up.right", accessibilityHint: "Opens in an in-app browser"
                ) { perform(.linkedIn, contact) }
            }
            if let github = contact.githubURL {
                ContactButton(
                    title: "GitHub", detail: github.displayString, systemImage: "chevron.left.forwardslash.chevron.right",
                    trailingImage: "arrow.up.right", accessibilityHint: "Opens in an in-app browser"
                ) { perform(.github, contact) }
            }
            if let website = contact.websiteURL {
                shareLink(website: website, portfolio: portfolio)
            }
        }
    }

    private func shareLink(website: URL, portfolio: Portfolio) -> some View {
        let title = portfolio.firstName.isEmpty ? "Share portfolio" : "Share \(portfolio.firstName)'s portfolio"
        return ShareLink(item: website) {
            ContactRowLabel(
                title: title, detail: website.displayString,
                systemImage: "square.and.arrow.up", trailingImage: "arrow.up.right"
            )
        }
        .buttonStyle(PressableRowStyle())
        .accessibilityLabel(title)
        .accessibilityHint("Opens the share sheet")
    }

    private func perform(_ action: ContactAction, _ contact: Contact) {
        model.perform(action, in: contact) { url, completion in
            openURL(url, completion: completion)
        }
    }
}

#Preview("Light") {
    ContactView(viewModel: .preview())
}

#Preview("Dark") {
    ContactView(viewModel: .preview())
        .preferredColorScheme(.dark)
}

#Preview("Loading") {
    ContactView(viewModel: .previewLoading())
}

#Preview("Failed") {
    ContactView(viewModel: .previewFailed())
}

#Preview("Empty") {
    ContactView(viewModel: .preview(Portfolio(headline: "iOS Engineer", about: ["Hello"])))
}
