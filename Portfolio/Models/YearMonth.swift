import Foundation

/// A calendar month parsed from the content document's `yyyy-MM` strings.
struct YearMonth: Equatable, Comparable, Sendable {
    let year: Int
    let month: Int

    init?(year: Int, month: Int) {
        guard (1900...2200).contains(year), (1...12).contains(month) else { return nil }
        self.year = year
        self.month = month
    }

    /// Parses `yyyy-MM`; returns `nil` for anything else.
    init?(string: String) {
        let parts = string.trimmingCharacters(in: .whitespaces).split(separator: "-")
        guard
            parts.count == 2,
            parts[0].count == 4,
            let year = Int(parts[0]),
            let month = Int(parts[1])
        else { return nil }
        self.init(year: year, month: month)
    }

    static func < (lhs: YearMonth, rhs: YearMonth) -> Bool {
        (lhs.year, lhs.month) < (rhs.year, rhs.month)
    }

    /// Locale-aware abbreviated month and year ("Oct 2021"). Formatting is pinned
    /// to UTC so the time zone can never shift the month.
    var displayString: String { localizedText(locale: .current) }

    func localizedText(locale: Locale) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Self.utc
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: 15, hour: 12)) else {
            return "\(month)/\(year)"
        }
        let style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: Self.utc)
            .month(.abbreviated)
            .year()
        return date.formatted(style)
    }

    private static let utc = TimeZone(secondsFromGMT: 0) ?? .gmt
}

enum DateRangeFormatter {
    static let presentLabel = "Present"

    /// Formats a start/end pair. A missing end date with a start date means "Present".
    /// An unparseable value is shown as written rather than dropped.
    static func text(start: String?, end: String?, locale: Locale = .current) -> String {
        let startText = label(for: start, locale: locale)
        let endText = label(for: end, locale: locale)
        switch (startText, endText) {
        case let (s?, e?): return s == e ? s : "\(s) – \(e)"
        case let (s?, nil): return "\(s) – \(presentLabel)"
        case let (nil, e?): return e
        case (nil, nil): return ""
        }
    }

    private static func label(for raw: String?, locale: Locale) -> String? {
        guard let raw, !raw.isBlank else { return nil }
        return YearMonth(string: raw)?.localizedText(locale: locale) ?? raw.trimmingCharacters(in: .whitespaces)
    }
}
