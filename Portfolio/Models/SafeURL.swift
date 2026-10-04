import Foundation

/// Builds URLs from strings that arrive in the (remote, untrusted) content
/// document. Anything that is not obviously safe returns `nil`, and the UI
/// simply omits the matching action.
enum SafeURL {
    /// http(s) URLs with a host. `SFSafariViewController` raises an exception
    /// for any other scheme, so this guard is also a crash guard.
    static func web(from string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !trimmed.isEmpty,
            let components = URLComponents(string: trimmed),
            let scheme = components.scheme?.lowercased(),
            scheme == "https" || scheme == "http",
            let host = components.host, !host.isEmpty
        else { return nil }
        return components.url
    }

    /// `mailto:` for a plain address. Rejects anything that could smuggle extra
    /// mail headers (`?cc=`, `&bcc=`), multiple recipients, or whitespace.
    static func mail(from string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        let forbidden = CharacterSet.whitespacesAndNewlines
            .union(.controlCharacters)
            .union(CharacterSet(charactersIn: "?&#,;<>\"'%/\\"))
        let parts = trimmed.split(separator: "@", omittingEmptySubsequences: false)
        guard
            parts.count == 2,
            !parts[0].isEmpty,
            parts[1].contains("."),
            trimmed.rangeOfCharacter(from: forbidden) == nil
        else { return nil }
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = trimmed
        return components.url
    }

    /// `tel:` for a phone number. Keeps digits and a single leading `+`.
    static func phone(from string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = trimmed.filter(\.isASCIIDigit)
        guard (7...15).contains(digits.count) else { return nil }
        let number = (trimmed.hasPrefix("+") ? "+" : "") + digits
        var components = URLComponents()
        components.scheme = "tel"
        components.path = number
        return components.url
    }
}

private extension Character {
    var isASCIIDigit: Bool { ("0"..."9").contains(self) }
}

extension URL {
    /// A compact, human-readable form for labels: no scheme, no `www.`, no trailing slash
    /// (`https://www.linkedin.com/in/name/` → `linkedin.com/in/name`).
    var displayString: String {
        var text = absoluteString
        for prefix in ["https://", "http://"] where text.lowercased().hasPrefix(prefix) {
            text.removeFirst(prefix.count)
        }
        if text.lowercased().hasPrefix("www.") { text.removeFirst(4) }
        while text.hasSuffix("/") { text.removeLast() }
        return text
    }
}
