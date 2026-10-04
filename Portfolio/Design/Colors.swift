import SwiftUI
import UIKit

/// The website's exact colour tokens, resolved per appearance by the system.
///
/// | Token      | Light     | Dark      |
/// |------------|-----------|-----------|
/// | background | `#F9F6EF` | `#0B0B0D` |
/// | text       | `#14110E` | `#F4F1EC` |
/// | gold       | `#9C7A2E` | `#E8C87A` |
///
/// The app follows the system appearance; there is no in-app theme toggle.
enum PortfolioPalette {
    static let backgroundLight: UInt32 = 0xF9F6EF
    static let backgroundDark: UInt32 = 0x0B0B0D
    static let textLight: UInt32 = 0x14110E
    static let textDark: UInt32 = 0xF4F1EC
    static let goldLight: UInt32 = 0x9C7A2E
    static let goldDark: UInt32 = 0xE8C87A
}

extension Color {
    /// Screen background.
    static let portfolioBackground = Color(light: PortfolioPalette.backgroundLight, dark: PortfolioPalette.backgroundDark)
    /// Primary text.
    static let portfolioText = Color(light: PortfolioPalette.textLight, dark: PortfolioPalette.textDark)
    /// Accent. Use for decoration and large text; it is below 4.5:1 against the
    /// light background, so small body copy uses `portfolioText` instead.
    static let portfolioGold = Color(light: PortfolioPalette.goldLight, dark: PortfolioPalette.goldDark)
    /// Secondary text: the primary text token at reduced strength.
    static let portfolioSecondaryText = portfolioText.opacity(0.72)
    /// Card fill: a faint wash of the gold token over the background.
    static let portfolioSurface = portfolioGold.opacity(0.08)
    /// Hairlines and card borders.
    static let portfolioHairline = portfolioGold.opacity(0.35)

    /// A colour that resolves to `light` or `dark` hex values with the trait collection.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
