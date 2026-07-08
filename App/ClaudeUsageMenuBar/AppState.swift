import Foundation
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
    }

    private func restartPollingIfNeeded() {
        guard authStatus == .signedIn else { return }
        startPolling()
    }
}
