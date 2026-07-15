import Foundation
import WidgetKit

/// Owns refreshing: fetch -> map -> write to shared storage -> tell
/// WidgetKit to reload. Only ever instantiated by the app target — the
/// widget extension never fetches on its own. Two things trigger a
/// refresh: the periodic poll timer (`pollInterval`, 5 minutes by
/// default), and a Darwin notification the widget extension posts every
/// time the system asks it to render — i.e. whenever it's actually
/// visible — via `WidgetRefreshRequestObserver` (only takes effect while
/// the app is running to hear it; there's no way for a widget to launch
/// its app just by being visible). Either path is subject to the same
/// rate limit so they can't double up on a redundant fetch when they
/// land close together.
@MainActor
public final class UsageRefreshCoordinator {
    private let client: AIMeterClient
    private let store: SharedUsageStore
    private var pollTask: Task<Void, Never>?
    private var credentialsProvider: (() -> ClaudeSessionCredentials?)?
    private var widgetRefreshObserverToken: AnyObject?
    private var lastAttemptDate: Date?

    /// Skip an actual fetch if the last attempt (success or failure) was
    /// more recent than this. Injectable so tests aren't stuck waiting
    /// out a real 30s window to observe a second fetch.
    private let minimumRefreshInterval: TimeInterval

    public private(set) var lastSnapshot: UsageSnapshot?
    public private(set) var lastError: FetchErrorState = .none

    public init(client: AIMeterClient, store: SharedUsageStore = SharedUsageStore(), minimumRefreshInterval: TimeInterval = 30) {
        self.client = client
        self.store = store
        self.minimumRefreshInterval = minimumRefreshInterval
        self.lastSnapshot = store.loadLatest()
        self.lastError = store.loadError()
    }

    /// True if the last fetch attempt (success or failure) was too recent
    /// to allow another one yet.
    private var isRateLimited: Bool {
        guard let lastAttemptDate else { return false }
        return Date().timeIntervalSince(lastAttemptDate) < minimumRefreshInterval
    }

    @discardableResult
    public func refresh(credentials: ClaudeSessionCredentials) async -> FetchErrorState {
        if isRateLimited {
            return lastError
        }
        lastAttemptDate = Date()
        do {
            let snapshot = try await client.fetchUsageSnapshot(
                credentials: credentials,
                organizationId: credentials.organizationId
            )
            lastSnapshot = snapshot
            lastError = .none
            try? store.save(snapshot)
            store.saveError(.none)
        } catch let error as AIMeterDecodingError {
            lastError = error.fetchErrorState
            store.saveError(error.fetchErrorState)
        } catch {
            lastError = .network
            store.saveError(.network)
        }
        reloadWidgets()
        return lastError
    }

    public func startPolling(interval: TimeInterval, credentialsProvider: @escaping () -> ClaudeSessionCredentials?) {
        stopPolling()
        self.credentialsProvider = credentialsProvider

        widgetRefreshObserverToken = WidgetRefreshRequestObserver.observe { [weak self] in
            Task { @MainActor in
                await self?.refreshIfDue()
            }
        }

        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshIfDue()
                try? await Task.sleep(nanoseconds: UInt64(max(interval, 30)) * 1_000_000_000)
            }
        }
    }

    /// Entry point for triggers that don't already have credentials in
    /// hand (the poll loop, the widget-visibility signal). Checks the
    /// rate limit *before* calling `credentialsProvider` — WidgetKit can
    /// call the widget's `getTimeline` several times in a quick burst
    /// (observed during development), and each one posts a refresh
    /// signal. Without this gate, a burst of signals meant a burst of
    /// Keychain reads too, not just fetch attempts — each of which could
    /// surface as its own macOS authorization prompt.
    private func refreshIfDue() async {
        guard !isRateLimited, let credentials = credentialsProvider?() else { return }
        await refresh(credentials: credentials)
    }

    public func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
        widgetRefreshObserverToken = nil
        credentialsProvider = nil
    }

    public func clearCachedState() {
        lastSnapshot = nil
        lastError = .none
        store.clearSnapshot()
        store.saveError(.none)
        reloadWidgets()
    }

    private func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
