import SwiftUI

/// Named type roles. Views ask for a role, never a raw font, so adopting the
/// website's typefaces later means changing this one file.
///
/// To swap in custom fonts, replace each `Font.system(...)` with
/// `Font.custom("FontName", size: n, relativeTo: textStyle)` so Dynamic Type keeps working.
enum Typography {
    /// Hero name.
    static let display = Font.system(.largeTitle, design: .serif).weight(.bold)
    /// Hero headline ("iOS Engineer").
    static let headline = Font.system(.title2, design: .serif).weight(.semibold)
    /// Section titles.
    static let sectionTitle = Font.system(.title2, design: .serif).weight(.semibold)
    /// Card and timeline titles.
    static let itemTitle = Font.system(.title3, design: .serif).weight(.semibold)
    /// Running copy.
    static let body = Font.system(.body, design: .default)
    /// Emphasised supporting line (company, project status).
    static let bodyEmphasis = Font.system(.body, design: .default).weight(.semibold)
    /// Dates, details, captions.
    static let caption = Font.system(.subheadline, design: .default)
    /// Small uppercase labels and chips.
    static let label = Font.system(.footnote, design: .default).weight(.semibold)
    /// Buttons.
    static let button = Font.system(.body, design: .default).weight(.semibold)
}
