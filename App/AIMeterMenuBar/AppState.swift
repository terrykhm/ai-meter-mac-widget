import Foundation
import AppKit
import WebKit
import WidgetKit
import AIMeterKit

enum AuthStatus: Equatable {
    case signedOut
    case signingIn
    case signedIn
}

@MainActor
final class AppState: ObservableObject {
    @Published var authStatus: AuthStatus = .signedOut
    @Published var snapshot: UsageSnapshot?
    @Published var lastError: FetchErrorState = .none

    var pollInterval: TimeInterval {
        didSet { restartPollingIfNeeded() }
    }

    private let keychain = KeychainSessionStore()
    private let client: AIMeterClient = AIMeterAPIClient()
    private let coordinator: UsageRefreshCoordinator
    private let loginWindowController = LoginWindowController()
    private let loginPagePrefetcher = LoginPagePrefetcher()
    private var widgetPresenceTask: Task<Void, Never>?

    init() {
        self.coordinator = UsageRefreshCoordinator(client: client)
        self.pollInterval = 300 // 5 minutes

        // No user-facing toggle for this — with no menu bar icon or Dock
        // icon, the only way back into the app after a restart is Launch
        // at Login, so it's just always on rather than something to opt
        // into. `enable()` is a no-op if already registered, and
        // best-effort fails silently if the app isn't in /Applications
        // yet (e.g. running from Xcode's DerivedData during development).
        LaunchAtLoginManager.enable()

        if let credentials = keychain.load(), !credentials.organizationId.isEmpty {
            authStatus = .signedIn
            startPolling()
            Task { await refresh() }
        } else {
            // No valid session — don't let a stale cached snapshot from
            // a previous sign-in linger and make the widget look like
            // it's showing live data for an account nobody's signed
            // into anymore. Normally `signOut()` is what clears this,
            // but the Keychain item can also go away by other means
            // (deleted outside the app, iCloud Keychain removal, etc.).
            coordinator.clearCachedState()
        }

        self.snapshot = coordinator.lastSnapshot
        self.lastError = coordinator.lastError
    }

    /// Called when Settings opens while signed out, so the login page's
    /// assets are already warm in cache by the time the user actually
    /// clicks "Sign in" — see `LoginPagePrefetcher`.
    func prefetchSignInPageIfNeeded() {
        guard authStatus == .signedOut else { return }
        loginPagePrefetcher.prefetch()
    }

    func beginSignIn() {
        authStatus = .signingIn
        loginPagePrefetcher.stop()
        loginWindowController.present(
            onComplete: { [weak self] credentials in
                Task { await self?.completeSignIn(credentials: credentials) }
            },
            onCancel: { [weak self] in
                self?.authStatus = .signedOut
            }
        )
    }

    func signOut() {
        keychain.clear()
        WKWebsiteDataStore.default().removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: .distantPast,
            completionHandler: {}
        )
        coordinator.stopPolling()
        coordinator.clearCachedState()
        widgetPresenceTask?.cancel()
        widgetPresenceTask = nil
        authStatus = .signedOut
        snapshot = nil
        lastError = .none
    }

    func refresh() async {
        guard let credentials = keychain.load() else { return }
        let error = await coordinator.refresh(credentials: credentials)
        if error == .sessionExpired {
            // claude.ai confirmed this session is no longer valid (401,
            // not just a network hiccup — see AIMeterDecodingError) —
            // treat it exactly like the user hit "Sign out", clearing
            // the Keychain item and cached snapshot too, not just the
            // in-memory auth flag. Otherwise the stale Keychain item
            // makes the next launch briefly think it's signed in again
            // before the next failed refresh flips it back, and the
            // widget keeps showing the last snapshot as if it were live.
            signOut()
            return
        }
        snapshot = coordinator.lastSnapshot
        lastError = error
    }

    private func completeSignIn(credentials: ClaudeSessionCredentials) async {
        var resolved = credentials

        if resolved.organizationId.isEmpty {
            do {
                let organizations = try await client.fetchOrganizations(credentials: resolved)
                guard let first = organizations.first else {
                    authStatus = .signedOut
                    lastError = .unknown
                    return
                }
                resolved = ClaudeSessionCredentials(sessionKey: resolved.sessionKey, organizationId: first.id)
            } catch {
                authStatus = .signedOut
                lastError = .unknown
                return
            }
        }

        do {
            try keychain.save(resolved)
        } catch {
            authStatus = .signedOut
            lastError = .unknown
            return
        }

        authStatus = .signedIn
        startPolling()
        await refresh()
    }

    private func startPolling() {
        coordinator.startPolling(interval: pollInterval) { [weak self] in
            self?.keychain.load()
        }
        startWidgetPresenceMonitoring()
    }

    private func restartPollingIfNeeded() {
        guard authStatus == .signedIn else { return }
        startPolling()
    }

    /// There's no macOS hook that launches an app because a widget was
    /// added — the app always needs at least one manual launch. This is
    /// the other half: once running, periodically check whether an AI
    /// Meter widget is actually placed anywhere (desktop, Notification
    /// Center, ...) and quit if not, rather than polling claude.ai
    /// forever in the background for a widget nobody has.
    private func startWidgetPresenceMonitoring() {
        widgetPresenceTask?.cancel()
        widgetPresenceTask = Task { [weak self] in
            // Give the widget system a moment right after launch before
            // the first check — a widget that was just added (or that
            // hasn't been queried yet this boot) may not be reflected
            // immediately.
            try? await Task.sleep(nanoseconds: 2 * 60 * 1_000_000_000)
            while !Task.isCancelled {
                await self?.quitIfNoWidgetPresent()
                guard let interval = self?.pollInterval else { return }
                try? await Task.sleep(nanoseconds: UInt64(max(interval, 30)) * 1_000_000_000)
            }
        }
    }

    private func quitIfNoWidgetPresent() async {
        // Don't quit out from under the user while they're actively
        // looking at the Settings window.
        guard !NSApp.windows.contains(where: { $0.isVisible }) else { return }
        switch await widgetPresence() {
        case .present, .unknown:
            return
        case .absent:
            NSApp.terminate(nil)
        }
    }

    private enum WidgetPresence { case present, absent, unknown }

    private func widgetPresence() async -> WidgetPresence {
        await withCheckedContinuation { continuation in
            WidgetCenter.shared.getCurrentConfigurations { result in
                switch result {
                case .success(let widgets):
                    continuation.resume(returning: widgets.isEmpty ? .absent : .present)
                case .failure:
                    continuation.resume(returning: .unknown)
                }
            }
        }
    }
}
