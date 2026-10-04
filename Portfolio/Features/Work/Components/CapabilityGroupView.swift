import SwiftUI

/// Lays subviews out left to right, wrapping to a new row when the line is full.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        return arrange(width: width, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(width: bounds.width, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(width: frame.width, height: frame.height)
            )
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> (frames: [CGRect], size: CGSize) {
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var usedWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: width.isFinite ? width : nil, height: nil))
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            usedWidth = max(usedWidth, x - spacing)
        }
        return (frames, CGSize(width: usedWidth, height: y + rowHeight))
    }
}

/// A titled group of skills rendered as wrapping chips.
struct CapabilityGroupView: View {
    let group: CapabilityGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(group.title)
                .font(Typography.bodyEmphasis)
                .foregroundStyle(Color.portfolioText)
                .accessibilityAddTraits(.isHeader)
            FlowLayout(spacing: 8) {
                ForEach(Array(group.items.enumerated()), id: \.offset) { _, item in
                    Text(item)
                        .font(Typography.caption)
                        .foregroundStyle(Color.portfolioText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Color.portfolioSurface))
                        .overlay(Capsule().strokeBorder(Color.portfolioHairline, lineWidth: 1))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(group.title): \(group.items.joined(separator: ", "))")
    }
}

#Preview("Capabilities") {
    VStack(alignment: .leading, spacing: 24) {
        ForEach(Array(Portfolio.sample.capabilityGroups.prefix(2).enumerated()), id: \.offset) { _, group in
            CapabilityGroupView(group: group)
        }
    }
    .padding()
    .portfolioScreen()
}
