import Foundation
import Observation

/// The actions on the Contact tab.
enum ContactAction: Equatable, Sendable {
    case email
    case call
    case linkedIn
    case github
}

/// A web page to show in the in-app Safari sheet.
struct WebDestination: Identifiable, Equatable {
    let url: URL
    var id: URL { url }
}

/// Owns the Contact tab's transient UI state: the in-app browser destination and
/// any "couldn't do that" message.
@MainActor
@Observable
final class ContactViewModel {
    /// Non-nil while the in-app Safari sheet should be showing.
    var webDestination: WebDestination?
    /// Non-nil while an alert should be showing.
    var alertMessage: String?

    /// The URL for `action`, or `nil` when the content has no valid value for it.
    func url(for action: ContactAction, in contact: Contact) -> URL? {
        switch action {
        case .email: contact.mailURL
        case .call: contact.phoneURL
        case .linkedIn: contact.linkedInURL
        case .github: contact.githubURL
        }
    }

    /// Routes an action. Web links present in-app; mail and phone are handed to
    /// `open`, which reports whether the system could handle the URL.
    func perform(
        _ action: ContactAction,
        in contact: Contact,
        open: (URL, @escaping @Sendable (Bool) -> Void) -> Void
    ) {
        guard let url = url(for: action, in: contact) else {
            alertMessage = Self.unavailableMessage(for: action)
            return
        }
        switch action {
        case .linkedIn, .github:
            webDestination = WebDestination(url: url)
        case .email, .call:
            open(url) { [weak self] accepted in
                guard !accepted else { return }
                Task { @MainActor in self?.alertMessage = Self.unavailableMessage(for: action) }
            }
        }
    }

    func dismissAlert() {
        alertMessage = nil
    }

    static func unavailableMessage(for action: ContactAction) -> String {
        switch action {
        case .email: "Email isn't available on this device."
        case .call: "Calling isn't available on this device."
        case .linkedIn, .github: "That link isn't available right now."
        }
    }
}
