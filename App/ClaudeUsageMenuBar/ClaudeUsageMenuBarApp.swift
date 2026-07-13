import SwiftUI

/// No menu bar icon and no Dock icon (LSUIElement) — this app runs purely
/// in the background, polling and writing the file the widget reads. Its
/// only UI is the Settings window, reachable by relaunching the app
/// (double-click in Finder/Spotlight while it's already running triggers
/// `AppDelegate.applicationShouldHandleReopen`).
@main
struct ClaudeUsageMenuBarApp: App {
    @StateObject private var appState = AppState()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}
