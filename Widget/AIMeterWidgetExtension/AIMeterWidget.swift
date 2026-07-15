import WidgetKit
import SwiftUI

struct AIMeterWidget: Widget {
    let kind: String = "AIMeterWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AIMeterTimelineProvider()) { entry in
            AIMeterWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Claude")
        .description("See your Claude session usage and time until reset.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
