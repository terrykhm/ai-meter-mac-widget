import Foundation
import AppKit
import WidgetKit
import ClaudeUsageKit

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
    private let client: ClaudeUsageClient = ClaudeUsageAPIClient()
    private let coordinator: UsageRefreshCoordinator
    private let loginWindowController = LoginWindowController()
    private var widgetPresenceTask: Task<Void, Never>?

    init() {
        self.coordinator = UsageRefreshCoordinator(client: client)
        self.pollInterval = 300 // 5 minutes

        self.snapshot = coordinator.lastSnapshot
        self.lastError = coordinator.lastError

        if let credentials = keychain.load(), !credentials.organizationId.isEmpty {
            authStatus = .signedIn
            startPolling()
            Task { await refresh() }
        }
    }

    func beginSignIn() {
        authStatus = .signingIn
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
        snapshot = coordinator.lastSnapshot
        lastError = error
        if error == .sessionExpired {
            authStatus = .signedOut
        }
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
