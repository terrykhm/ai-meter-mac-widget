import AppKit
import AIMeterKit

/// With no menu bar icon and no Dock icon, the app has no visible surface
/// to click on to reach its Settings window. AppKit reports a relaunch
/// (double-clicking the app again in Finder/Spotlight while it's already
/// running) as a "reopen" event — handle that by showing Settings.
///
/// Also shows Settings once on a genuinely fresh launch (no saved
/// session yet) so a new install can find the sign-in button at all, but
/// NOT on ordinary background launches once already signed in (e.g. via
/// Launch at Login) — otherwise the app would pop a window open at every
/// login, defeating the point of having no menu bar icon.
///
/// Also registered for the `aimeter://` URL scheme (see Info.plist's
/// CFBundleURLTypes) — the widget's signed-out state links to
/// `aimeter://open` since it can't host the real sign-in flow itself
/// (that's a full WKWebView login window, app-only).
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Set from `AIMeterMenuBarApp.init()` before any lifecycle
    /// method below can fire.
    static var appState: AppState?

    private let settingsWindowController = SettingsWindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        if KeychainSessionStore().load() == nil {
            showSettings()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        showSettings()
    }

    private func showSettings() {
        guard let appState = Self.appState else { return }
        settingsWindowController.show(appState: appState)
    }
}
