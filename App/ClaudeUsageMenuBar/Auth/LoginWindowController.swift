import SwiftUI
import AppKit
import ClaudeUsageKit

/// Presents the sign-in flow in its own window. The menu bar popover isn't
/// a real window we could attach a sheet to, so sign-in opens a standalone
/// window instead.
@MainActor
final class LoginWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var onCancel: (() -> Void)?
    private var didComplete = false

    func present(onComplete: @escaping (ClaudeSessionCredentials) -> Void, onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
        self.didComplete = false

        let rootView = LoginFlowView(onComplete: { [weak self] credentials in
            self?.didComplete = true
            self?.window?.close()
            onComplete(credentials)
        })

        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Sign in to Claude"
        window.setContentSize(NSSize(width: 480, height: 620))
        window.styleMask = [.titled, .closable]
        window.delegate = self
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        if !didComplete {
            onCancel?()
        }
        onCancel = nil
    }
}

private struct LoginFlowView: View {
    var onComplete: (ClaudeSessionCredentials) -> Void

    @State private var showManualFallback = false

    var body: some View {
        VStack(spacing: 0) {
            if showManualFallback {
                ManualSessionKeyView(onSubmit: onComplete, onBack: { showManualFallback = false })
            } else {
                LoginWebView { sessionKey, lastActiveOrg in
                    onComplete(ClaudeSessionCredentials(sessionKey: sessionKey, organizationId: lastActiveOrg ?? ""))
                }

                Divider()

                Button("Having trouble signing in? Enter session key manually") {
                    showManualFallback = true
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(10)
            }
        }
        .frame(width: 480, height: 620)
    }
}
