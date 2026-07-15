import XCTest
@testable import AIMeterKit

@MainActor
final class UsageRefreshCoordinatorTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        tempDirectory = nil
        super.tearDown()
    }

    func testRefreshSkipsFetchWithinRateLimitWindow() async {
        let client = CountingFakeClient()
        let coordinator = UsageRefreshCoordinator(client: client, store: makeStore())
        let credentials = ClaudeSessionCredentials(sessionKey: "abc", organizationId: "org-1")

        _ = await coordinator.refresh(credentials: credentials)
        _ = await coordinator.refresh(credentials: credentials)
        _ = await coordinator.refresh(credentials: credentials)

        XCTAssertEqual(client.fetchCount, 1, "back-to-back refresh calls within 30s should only fetch once")
    }

    func testRefreshFetchesAgainOnceRateLimitWindowPasses() async throws {
        let client = CountingFakeClient()
        // Near-zero window so the test doesn't have to sleep 30+ real seconds.
        let coordinator = UsageRefreshCoordinator(client: client, store: makeStore(), minimumRefreshInterval: 0.05)
        let credentials = ClaudeSessionCredentials(sessionKey: "abc", organizationId: "org-1")

        _ = await coordinator.refresh(credentials: credentials)
        try await Task.sleep(nanoseconds: 100_000_000)
        _ = await coordinator.refresh(credentials: credentials)

        XCTAssertEqual(client.fetchCount, 2)
    }

    func testWidgetRefreshRequestTriggersARefresh() async throws {
        let client = CountingFakeClient()
        // Near-zero window: this test's whole point is to observe the
        // Darwin-notification path itself causing a second fetch, which
        // the real 30s rate limit would otherwise mask.
        let coordinator = UsageRefreshCoordinator(client: client, store: makeStore(), minimumRefreshInterval: 0.05)
        let credentials = ClaudeSessionCredentials(sessionKey: "abc", organizationId: "org-1")

        coordinator.startPolling(interval: 3600, credentialsProvider: { credentials })
        defer { coordinator.stopPolling() }

        // The poll loop fetches immediately on start; let that land first
        // so it isn't confused with the signal this test cares about.
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(client.fetchCount, 1)

        WidgetRefreshRequestObserver.postRefreshRequest()
        try await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertEqual(client.fetchCount, 2, "the widget's Darwin notification should have triggered a second fetch")
    }

    func testBurstOfWidgetRefreshRequestsOnlyResolvesCredentialsOnce() async throws {
        let client = CountingFakeClient()
        let coordinator = UsageRefreshCoordinator(client: client, store: makeStore(), minimumRefreshInterval: 30)
        var credentialsLookupCount = 0
        let credentials = ClaudeSessionCredentials(sessionKey: "abc", organizationId: "org-1")

        coordinator.startPolling(interval: 3600, credentialsProvider: {
            credentialsLookupCount += 1
            return credentials
        })
        defer { coordinator.stopPolling() }

        // The poll loop resolves credentials once immediately on start.
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(credentialsLookupCount, 1)

        // WidgetKit can call getTimeline several times in a quick burst;
        // each one posts a refresh signal. None of those extra signals
        // should touch credentialsProvider (i.e. Keychain) again while
        // still inside the 30s rate-limit window — that was the bug: the
        // Keychain read used to happen before the rate-limit check, so a
        // burst of widget signals meant a burst of Keychain reads too.
        for _ in 0..<5 {
            WidgetRefreshRequestObserver.postRefreshRequest()
        }
        try await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertEqual(credentialsLookupCount, 1, "a burst of widget signals within the rate-limit window should not repeatedly touch Keychain")
        XCTAssertEqual(client.fetchCount, 1)
    }

    private func makeStore() -> SharedUsageStore {
        SharedUsageStore(directoryURL: tempDirectory)
    }
}

private final class CountingFakeClient: AIMeterClient {
    private(set) var fetchCount = 0

    func fetchOrganizations(credentials: ClaudeSessionCredentials) async throws -> [AccountOrganization] {
        []
    }

    func fetchUsageSnapshot(credentials: ClaudeSessionCredentials, organizationId: String) async throws -> UsageSnapshot {
        fetchCount += 1
        return UsageSnapshot(
            windows: [WindowUsage(kind: .fiveHour, utilization: 0.1, resetsAt: nil)],
            fetchedAt: Date(),
            organizationId: organizationId
        )
    }
}
