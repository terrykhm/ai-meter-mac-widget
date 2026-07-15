import SwiftUI
import AppKit
import AIMeterKit

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
        // Deliberately NOT .fullSizeContentView / transparent titlebar —
        // tried it for the warm-frosted restyle and it silently broke
        // SettingsWindowController's window (same base construction
        // pattern): no crash, the window just never appeared, across
        // every trigger path. Not worth the same risk here for a
        // cosmetic titlebar effect; the SwiftUI content still carries
        // the warm-frosted look under a normal titlebar.
        window.title = "Sign in to Claude"
        window.setContentSize(NSSize(width: 480, height: 640))
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
    @State private var isLoading = true

    var body: some View {
        ZStack {
            UsageColors.cardBackgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.top, 22)
                    .padding(.bottom, 14)

                if showManualFallback {
                    ManualSessionKeyView(onSubmit: onComplete, onBack: { showManualFallback = false })
                } else {
                    ZStack {
                        LoginWebView(isLoading: $isLoading) { sessionKey, lastActiveOrg in
                            onComplete(ClaudeSessionCredentials(sessionKey: sessionKey, organizationId: lastActiveOrg ?? ""))
                        }

                        if isLoading {
                            loadingOverlay
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.6), lineWidth: 1)
                    )
                    .shadow(color: UsageColors.glassPanelShadow, radius: 20, x: 0, y: 8)
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Button("Having trouble signing in? Enter session key manually") {
                        showManualFallback = true
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(UsageColors.textSecondary())
                    .padding(18)
                }
            }
        }
        .frame(width: 480, height: 640)
    }

    /// Sits over the web view (not the whole window) so the header and
    /// fallback link stay visible and usable while claude.ai loads —
    /// only ever meaningfully visible on a cold cache, since a warm one
    /// finishes fast enough to barely register.
    private var loadingOverlay: some View {
        VStack(spacing: 10) {
            ProgressView()
                .controlSize(.regular)
            Text("Loading claude.ai…")
                .font(.system(size: 12))
                .foregroundStyle(UsageColors.textSecondary())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(UsageColors.cardBackgroundGradient)
    }

    /// Centered rather than leading-aligned to keep it visually balanced
    /// under the (normal, non-transparent) titlebar.
    private var header: some View {
        HStack(spacing: 7) {
            Image("AIMeterLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
            Text("AI Meter")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(UsageColors.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }
}
