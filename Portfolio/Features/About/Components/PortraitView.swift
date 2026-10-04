import SwiftUI
import UIKit

/// The owner's portrait. Shows the `Portrait` image from the asset catalog when
/// one exists, otherwise a monogram placeholder built from the name's initials.
struct PortraitView: View {
    let name: String
    let initials: String
    var size: CGFloat = 120

    var body: some View {
        Group {
            if let image = UIImage(named: "Portrait") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .accessibilityLabel(name.isBlank ? "Portrait" : "Portrait of \(name)")
            } else {
                ZStack {
                    Color.portfolioSurface
                    Text(initials)
                        .font(.system(size: size * 0.38, weight: .semibold, design: .serif))
                        .foregroundStyle(Color.portfolioGold)
                }
                .accessibilityHidden(true)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color.portfolioGold, lineWidth: 2))
    }
}

#Preview("Placeholder") {
    PortraitView(name: "Adrian Gutierrez", initials: "AG")
        .padding()
        .portfolioScreen()
}
