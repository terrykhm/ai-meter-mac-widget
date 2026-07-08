import Foundation
import WidgetKit

/// Owns periodic polling: fetch -> map -> write to the App Group -> tell
/// WidgetKit to reload. Only ever instantiated by the app target — the
/// widget extension never fetches on its own, it only reads what this
/// writes.
@MainActor
public final class UsageRefreshCoordinator {
    private let client: ClaudeUsageClient
    private let store: SharedUsageStore
    private var pollTask: Task<Void, Never>?

    public private(set) var lastSnapshot: UsageSnapshot?
    public private(set) var lastError: FetchErrorState = .none

    public init(client: ClaudeUsageClient, store: SharedUsageStore = SharedUsageStore()) {
        self.client = client
        self.store = store
        self.lastSnapshot = store.loadLatest()
        self.lastError = store.loadError()
    }

    @discardableResult
    public func refresh(credentials: ClaudeSessionCredentials) async -> FetchErrorState {
        do {
            let snapshot = try await client.fetchUsageSnapshot(
                credentials: credentials,
                organizationId: credentials.organizationId
            )
            lastSnapshot = snapshot
            lastError = .none
            try? store.save(snapshot)
            store.saveError(.none)
        } catch let error as ClaudeUsageDecodingError {
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
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                if let credentials = credentialsProvider() {
                    await self?.refresh(credentials: credentials)
                }
                try? await Task.sleep(nanoseconds: UInt64(max(interval, 30)) * 1_000_000_000)
            }
        }
    }

    public func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
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
