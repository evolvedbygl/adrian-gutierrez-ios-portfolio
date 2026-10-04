import Foundation

/// The app's four tabs. Also the deep-link vocabulary: `portfolio://contact`
/// opens the Contact tab (the widget uses this). Shared with the widget target.
enum AppTab: String, CaseIterable, Hashable, Sendable {
    case about
    case experience
    case work
    case contact

    static let urlScheme = "portfolio"

    var deepLinkURL: URL? {
        var components = URLComponents()
        components.scheme = Self.urlScheme
        components.host = rawValue
        return components.url
    }

    /// Parses `portfolio://<tab>`. Unknown schemes or hosts return `nil`.
    init?(deepLink url: URL) {
        guard
            url.scheme?.lowercased() == Self.urlScheme,
            let host = url.host?.lowercased(),
            let tab = AppTab(rawValue: host)
        else { return nil }
        self = tab
    }
}
