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

    func testFetchUsageSnapshotMapsValidResponse() async throws {
        let json = """
        {
          "organizationName": "Acme",
          "planName": "MAX",
          "windows": [
            {"kind": "five_hour", "utilization": 0.42, "resetsAt": "2026-07-08T20:00:00Z", "used": 128, "limit": 300},
            {"kind": "seven_day", "utilization": 0.61, "resetsAt": null, "used": null, "limit": null}
          ]
        }
        """.data(using: .utf8)!
        StubURLProtocol.stub = .init(statusCode: 200, data: json)

        let client = ClaudeUsageAPIClient(session: session)
        let credentials = ClaudeSessionCredentials(sessionKey: "abc", organizationId: "org-1")
        let snapshot = try await client.fetchUsageSnapshot(credentials: credentials, organizationId: "org-1")

        XCTAssertEqual(snapshot.organizationId, "org-1")
        XCTAssertEqual(snapshot.organizationName, "Acme")
        XCTAssertEqual(snapshot.windows.count, 2)
        XCTAssertEqual(snapshot.fiveHourWindow?.percentInt, 42)
        XCTAssertEqual(snapshot.fiveHourWindow?.used, 128)
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
