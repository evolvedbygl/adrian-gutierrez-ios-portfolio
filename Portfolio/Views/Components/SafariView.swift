import SafariServices
import SwiftUI

/// `SFSafariViewController` wrapped for SwiftUI.
///
/// Callers only ever pass URLs built by `SafeURL.web(from:)`, because
/// `SFSafariViewController` throws for anything that isn't http(s).
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let configuration = SFSafariViewController.Configuration()
        configuration.entersReaderIfAvailable = false
        let controller = SFSafariViewController(url: url, configuration: configuration)
        controller.preferredControlTintColor = UIColor(Color.portfolioGold)
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

extension View {
    /// Presents `destination` in an in-app Safari sheet.
    func safariSheet(item destination: Binding<WebDestination?>) -> some View {
        sheet(item: destination) { destination in
            SafariView(url: destination.url)
                .ignoresSafeArea()
        }
    }
}
