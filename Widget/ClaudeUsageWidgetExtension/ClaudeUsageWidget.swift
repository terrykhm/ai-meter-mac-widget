import WidgetKit
import SwiftUI

struct ClaudeUsageWidget: Widget {
    let kind: String = "ClaudeUsageWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ClaudeUsageTimelineProvider()) { entry in
            ClaudeUsageWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Claude Usage")
        .description("See your Claude session usage and time until reset.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
