import SwiftUI
import WidgetKit

// MARK: - Content

/// The widget is intentionally static (no App Group, no network): a small,
/// always-correct "available for hire" card that deep-links to the Contact tab.
enum AvailabilityWidgetContent {
    static let name = "Adrian Gutierrez"
    static let availability = "Open to iOS roles"
    static let callToAction = "Get in touch"
    static let kind = "AvailabilityWidget"
}

// MARK: - Timeline

struct AvailabilityEntry: TimelineEntry {
    let date: Date
}

struct AvailabilityProvider: TimelineProvider {
    func placeholder(in context: Context) -> AvailabilityEntry {
        AvailabilityEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (AvailabilityEntry) -> Void) {
        completion(AvailabilityEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AvailabilityEntry>) -> Void) {
        // Content never changes, so a single entry that never expires is enough.
        completion(Timeline(entries: [AvailabilityEntry(date: .now)], policy: .never))
    }
}

// MARK: - Views

struct AvailabilityWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .systemMedium: medium
            default: small
            }
        }
        .containerBackground(for: .widget) { Color.portfolioBackground }
        .widgetURL(AppTab.contact.deepLinkURL)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(AvailabilityWidgetContent.name), \(AvailabilityWidgetContent.availability)")
        .accessibilityHint("Opens the Contact tab")
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            availabilityDot
            Spacer(minLength: 0)
            Text(AvailabilityWidgetContent.availability)
                .font(.system(.headline, design: .serif).weight(.semibold))
                .foregroundStyle(Color.portfolioGold)
                .minimumScaleFactor(0.8)
            Text(AvailabilityWidgetContent.name)
                .font(.system(.footnote))
                .foregroundStyle(Color.portfolioText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var medium: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                availabilityDot
                Text(AvailabilityWidgetContent.availability)
                    .font(.system(.title3, design: .serif).weight(.semibold))
                    .foregroundStyle(Color.portfolioGold)
                    .minimumScaleFactor(0.8)
                Text(AvailabilityWidgetContent.name)
                    .font(.system(.subheadline, design: .serif).weight(.semibold))
                    .foregroundStyle(Color.portfolioText)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            VStack(spacing: 6) {
                Image(systemName: "envelope.fill")
                    .font(.title2)
                    .foregroundStyle(Color.portfolioGold)
                    .accessibilityHidden(true)
                Text(AvailabilityWidgetContent.callToAction)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.portfolioText)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var availabilityDot: some View {
        Circle()
            .fill(Color.portfolioGold)
            .frame(width: 10, height: 10)
            .accessibilityHidden(true)
    }
}

// MARK: - Widget

@main
struct PortfolioWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: AvailabilityWidgetContent.kind, provider: AvailabilityProvider()) { _ in
            AvailabilityWidgetView()
        }
        .configurationDisplayName("Availability")
        .description("Adrian is open to iOS roles. Tap to get in touch.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview("Small", as: .systemSmall) {
    PortfolioWidget()
} timeline: {
    AvailabilityEntry(date: .now)
}

#Preview("Medium", as: .systemMedium) {
    PortfolioWidget()
} timeline: {
    AvailabilityEntry(date: .now)
}
