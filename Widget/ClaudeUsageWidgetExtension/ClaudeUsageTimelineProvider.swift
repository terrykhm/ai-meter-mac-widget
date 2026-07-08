import WidgetKit
import ClaudeUsageKit

struct UsageWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: UsageSnapshot?
    let errorState: FetchErrorState
}

/// Reads whatever the app last wrote to the shared storage location. Never
/// makes a network call and never touches Keychain — if the app isn't
/// running, this just keeps re-showing (and re-scheduling reloads of) the
/// last known snapshot.
struct ClaudeUsageTimelineProvider: TimelineProvider {
    private let store = SharedUsageStore()

    func placeholder(in context: Context) -> UsageWidgetEntry {
        UsageWidgetEntry(
            date: Date(),
            snapshot: UsageSnapshot(
                windows: [
                    WindowUsage(
                        kind: .fiveHour,
                        utilization: 0.42,
                        resetsAt: Date().addingTimeInterval(6 * 3600 + 12 * 60),
                        used: 128,
                        limit: 300
                    )
                ],
                fetchedAt: Date(),
                organizationId: "placeholder",
                planName: "MAX"
            ),
            errorState: .none
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (UsageWidgetEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UsageWidgetEntry>) -> Void) {
        let entry = currentEntry()
        // Re-reads the same cache periodically so reset countdowns keep
        // advancing even if the app hasn't refreshed recently. The app
        // itself calls WidgetCenter.reloadAllTimelines() immediately after
        // writing fresh data, so this is just the fallback cadence.
        let nextReload = Date().addingTimeInterval(15 * 60)
        completion(Timeline(entries: [entry], policy: .after(nextReload)))
    }

    private func currentEntry() -> UsageWidgetEntry {
        UsageWidgetEntry(
            date: Date(),
            snapshot: store.loadLatest(),
            errorState: store.loadError()
        )
    }
}
