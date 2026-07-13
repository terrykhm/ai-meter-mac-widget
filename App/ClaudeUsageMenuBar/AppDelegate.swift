import AppKit
import ClaudeUsageKit

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
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if KeychainSessionStore().load() == nil {
            Self.showSettings()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        Self.showSettings()
        return true
    }

    private static func showSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}
