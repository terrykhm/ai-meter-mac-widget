import SwiftUI

/// No menu bar icon and no Dock icon (LSUIElement) — this app runs purely
/// in the background, polling and writing the file the widget reads. Its
/// only UI is the Settings window, hand-rolled via `SettingsWindowController`
/// (not SwiftUI's `Settings` scene — see that file for why), reachable by
/// relaunching the app (double-click in Finder/Spotlight while it's
/// already running triggers `AppDelegate.applicationShouldHandleReopen`)
/// or via the widget's "sign in" link (`aimeter://open`).
@main
struct ClaudeUsageMenuBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState: AppState

    init() {
        let appState = AppState()
        _appState = StateObject(wrappedValue: appState)
        AppDelegate.appState = appState
    }

    // A Scene is required, but this app has no SwiftUI-managed windows —
    // both Login and Settings are hand-rolled NSWindows (see
    // LoginWindowController / SettingsWindowController). This exists
    // purely to satisfy the `App` protocol and is never shown.
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
