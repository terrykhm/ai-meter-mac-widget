import XCTest
@testable import AIMeterKit

final class AIMeterAPIClientTests: XCTestCase {
    private var session: URLSession!

    override func setUp() {
        super.setUp()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        session = URLSession(configuration: configuration)
    }

    override func tearDown() {
        StubURLProtocol.stub = nil
        StubURLProtocol.organizationsStub = nil
        session = nil
        super.tearDown()
    }

    // Redacted, real response captured from GET
    // /api/organizations/{id}/usage (a logged-in claude.ai session,
    // Settings → Usage) — see Docs/ENDPOINT_NOTES.md. Only the fields the
    // DTO actually declares matter for this test; the rest (limits,
    // spend, extra_usage, etc.) are included to prove they're tolerated.
    func testFetchUsageSnapshotMapsValidResponse() async throws {
        let json = """
        {
          "five_hour": {"utilization": 40.0, "resets_at": "2026-07-12T07:00:00.069688+00:00", "limit_dollars": null, "used_dollars": null, "remaining_dollars": null},
          "seven_day": {"utilization": 5.0, "resets_at": "2026-07-14T06:00:00.069713+00:00", "limit_dollars": null, "used_dollars": null, "remaining_dollars": null},
          "seven_day_opus": null,
          "seven_day_sonnet": null,
          "extra_usage": {"is_enabled": false},
          "limits": [
            {"kind": "session", "group": "session", "percent": 40, "severity": "normal", "resets_at": "2026-07-12T07:00:00.069688+00:00", "scope": null, "is_active": true}
          ],
          "spend": {"used": {"amount_minor": 0, "currency": "USD", "exponent": 2}, "enabled": false},
          "member_dashboard_available": false
        }
        """.data(using: .utf8)!
        StubURLProtocol.stub = .init(statusCode: 200, data: json)

        let client = AIMeterAPIClient(session: session)
        let credentials = ClaudeSessionCredentials(sessionKey: "abc", organizationId: "org-1")
        let snapshot = try await client.fetchUsageSnapshot(credentials: credentials, organizationId: "org-1")

        XCTAssertEqual(snapshot.organizationId, "org-1")
        XCTAssertEqual(snapshot.windows.count, 2)
        XCTAssertEqual(snapshot.fiveHourWindow?.percentInt, 40)
        XCTAssertEqual(snapshot.sevenDayWindow?.percentInt, 5)
    }

    // Redacted, real response captured from GET /api/organizations —
    // `capabilities` is what the plan badge is derived from.
    func testFetchUsageSnapshotDerivesPlanBadgeFromOrganizationCapabilities() async throws {
        StubURLProtocol.stub = .init(statusCode: 200, data: """
        {"five_hour": {"utilization": 40.0, "resets_at": null}, "seven_day": {"utilization": 5.0, "resets_at": null}}
        """.data(using: .utf8)!)
        StubURLProtocol.organizationsStub = .init(statusCode: 200, data: """
        [{"uuid": "org-1", "name": "test@example.com's Organization", "capabilities": ["chat", "claude_pro"]}]
        """.data(using: .utf8)!)

        let client = AIMeterAPIClient(session: session)
        let credentials = ClaudeSessionCredentials(sessionKey: "abc", organizationId: "org-1")
        let snapshot = try await client.fetchUsageSnapshot(credentials: credentials, organizationId: "org-1")

        XCTAssertEqual(snapshot.planName, "PRO")
    }

    func testFetchUsageSnapshotLeavesPlanBadgeNilWhenOrganizationsFetchFails() async throws {
        StubURLProtocol.stub = .init(statusCode: 200, data: """
        {"five_hour": {"utilization": 40.0, "resets_at": null}, "seven_day": {"utilization": 5.0, "resets_at": null}}
        """.data(using: .utf8)!)
        StubURLProtocol.organizationsStub = .init(statusCode: 401, data: Data())

        let client = AIMeterAPIClient(session: session)
        let credentials = ClaudeSessionCredentials(sessionKey: "abc", organizationId: "org-1")
        let snapshot = try await client.fetchUsageSnapshot(credentials: credentials, organizationId: "org-1")

        XCTAssertNil(snapshot.planName)
        XCTAssertEqual(snapshot.windows.count, 2, "a failed plan-badge lookup must not fail the primary usage fetch")
    }

    func testFetchUsageSnapshotThrowsUnauthorizedOn401() async {
        StubURLProtocol.stub = .init(statusCode: 401, data: Data())
        let client = AIMeterAPIClient(session: session)
        let credentials = ClaudeSessionCredentials(sessionKey: "expired", organizationId: "org-1")

        do {
            _ = try await client.fetchUsageSnapshot(credentials: credentials, organizationId: "org-1")
            XCTFail("expected unauthorized error")
        } catch let error as AIMeterDecodingError {
            XCTAssertEqual(error, .unauthorized)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testFetchUsageSnapshotThrowsSchemaMismatchOnUnparseableBody() async {
        StubURLProtocol.stub = .init(statusCode: 200, data: "not json".data(using: .utf8)!)
        let client = AIMeterAPIClient(session: session)
        let credentials = ClaudeSessionCredentials(sessionKey: "abc", organizationId: "org-1")

        do {
            _ = try await client.fetchUsageSnapshot(credentials: credentials, organizationId: "org-1")
            XCTFail("expected schema mismatch error")
        } catch let error as AIMeterDecodingError {
            guard case .schemaMismatch = error else {
                return XCTFail("expected schemaMismatch, got \(error)")
            }
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}

private final class StubURLProtocol: URLProtocol {
    struct Stub {
        let statusCode: Int
        let data: Data
    }

    /// Response for `/usage` requests.
    static var stub: Stub?
    /// Response for `/organizations` requests. Falls back to `stub` when
    /// unset, so existing single-stub tests (which never hit this path
    /// far enough to matter) keep working unchanged.
    static var organizationsStub: Stub?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let isOrganizations = url.path.hasSuffix("/organizations")
        guard let stub = (isOrganizations ? StubURLProtocol.organizationsStub ?? StubURLProtocol.stub : StubURLProtocol.stub) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let response = HTTPURLResponse(url: url, statusCode: stub.statusCode, httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
