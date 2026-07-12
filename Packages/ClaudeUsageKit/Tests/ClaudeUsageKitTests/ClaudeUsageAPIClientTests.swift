import XCTest
@testable import ClaudeUsageKit

final class ClaudeUsageAPIClientTests: XCTestCase {
    private var session: URLSession!

    override func setUp() {
        super.setUp()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        session = URLSession(configuration: configuration)
    }

    override func tearDown() {
        StubURLProtocol.stub = nil
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

        let client = ClaudeUsageAPIClient(session: session)
        let credentials = ClaudeSessionCredentials(sessionKey: "abc", organizationId: "org-1")
        let snapshot = try await client.fetchUsageSnapshot(credentials: credentials, organizationId: "org-1")

        XCTAssertEqual(snapshot.organizationId, "org-1")
        XCTAssertEqual(snapshot.windows.count, 2)
        XCTAssertEqual(snapshot.fiveHourWindow?.percentInt, 40)
        XCTAssertEqual(snapshot.sevenDayWindow?.percentInt, 5)
    }

    func testFetchUsageSnapshotThrowsUnauthorizedOn401() async {
        StubURLProtocol.stub = .init(statusCode: 401, data: Data())
        let client = ClaudeUsageAPIClient(session: session)
        let credentials = ClaudeSessionCredentials(sessionKey: "expired", organizationId: "org-1")

        do {
            _ = try await client.fetchUsageSnapshot(credentials: credentials, organizationId: "org-1")
            XCTFail("expected unauthorized error")
        } catch let error as ClaudeUsageDecodingError {
            XCTAssertEqual(error, .unauthorized)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testFetchUsageSnapshotThrowsSchemaMismatchOnUnparseableBody() async {
        StubURLProtocol.stub = .init(statusCode: 200, data: "not json".data(using: .utf8)!)
        let client = ClaudeUsageAPIClient(session: session)
        let credentials = ClaudeSessionCredentials(sessionKey: "abc", organizationId: "org-1")

        do {
            _ = try await client.fetchUsageSnapshot(credentials: credentials, organizationId: "org-1")
            XCTFail("expected schema mismatch error")
        } catch let error as ClaudeUsageDecodingError {
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

    static var stub: Stub?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let stub = StubURLProtocol.stub, let url = request.url else {
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
