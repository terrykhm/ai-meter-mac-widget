import SwiftUI
import AppKit

/// Owns the Settings window directly via `NSHostingController`, the same
/// pattern `LoginWindowController` already uses successfully — rather than
/// SwiftUI's built-in `Settings` scene + the undocumented
/// `showSettingsWindow:` selector, which turned out to be unreliable for
/// this app: `NSApp.sendAction(Selector(("showSettingsWindow:")), ...)`
/// consistently reported success from `AppDelegate` (cold launch, reopen,
/// URL-scheme open) without ever actually producing a window, even after
/// retrying for over a second. Constructing the window directly sidesteps
/// that scene-wiring machinery entirely.
///
/// Match `LoginWindowController`'s exact recipe: fixed content size set
/// via `setContentSize` right after construction, no `.resizable` style,
/// no `NSHostingController.sizingOptions`. Both of those alternatives —
/// tried while debugging this — reliably crashed deep in AppKit's
/// constraint system (`NSGenericException` inside
/// `updateConstraintsForSubtreeIfNeeded`) for reasons that didn't fully
/// resolve even after also trying to isolate it to `SettingsView`'s
/// content (it wasn't the content). Whatever the underlying AppKit/
/// SwiftUI interaction bug is, this exact fixed-size/non-resizable
/// pattern is the one that's actually proven to work across cold
/// launch, reopen, and the `aimeter://` URL scheme — don't "simplify"
/// it back to auto-sizing without re-verifying all three triggers.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    func show(appState: AppState) {
        NSApp.activate(ignoringOtherApps: true)
        appState.prefetchSignInPageIfNeeded()

        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let rootView = SettingsView().environmentObject(appState)
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)
        // Deliberately NOT adding .fullSizeContentView / transparent
        // titlebar here — tried it for the warm-frosted restyle and it
        // silently broke this window (no crash, no window ever appeared,
        // across cold launch / reopen / the aimeter:// URL scheme). Given
        // this window's documented history of subtle AppKit layout bugs
        // (see type doc above), not worth the risk for a cosmetic
        // titlebar effect — the SwiftUI content below still carries the
        // warm-frosted look, just under a normal titlebar.
        window.title = "AI Meter"
        window.styleMask = [.titled, .closable]
        window.delegate = self
        window.setContentSize(NSSize(width: 380, height: 350))
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
