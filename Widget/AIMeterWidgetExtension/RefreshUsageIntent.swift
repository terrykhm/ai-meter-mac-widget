import AppIntents
import AIMeterKit

/// Backs the widget's refresh button. Runs in the widget extension's
/// process, same as `getTimeline` — it can't fetch usage data itself
/// (only the app talks to claude.ai), so it just posts the same Darwin
/// notification `getTimeline` already posts on every render. The app (if
/// running — which, now that it launches at login, it normally is)
/// picks that up, refreshes, writes the new snapshot, and reloads widget
/// timelines itself; this intent doesn't need to wait for any of that.
struct RefreshUsageIntent: AppIntent {
    static var title: LocalizedStringResource = "Refresh AI Meter"
    static var description = IntentDescription("Asks AI Meter to refresh your usage data.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        WidgetRefreshRequestObserver.postRefreshRequest()
        return .result()
    }
}
