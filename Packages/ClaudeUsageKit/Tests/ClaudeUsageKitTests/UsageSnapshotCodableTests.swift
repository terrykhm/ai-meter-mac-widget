import XCTest
@testable import ClaudeUsageKit

final class UsageSnapshotCodableTests: XCTestCase {
    func testRoundTripEncodingDecoding() throws {
        let snapshot = UsageSnapshot(
            windows: [
                WindowUsage(kind: .fiveHour, utilization: 0.42, resetsAt: Date(timeIntervalSince1970: 1_700_000_000), used: 128, limit: 300),
                WindowUsage(kind: .sevenDay, utilization: 0.61, resetsAt: Date(timeIntervalSince1970: 1_700_500_000))
            ],
            fetchedAt: Date(timeIntervalSince1970: 1_699_999_000),
            organizationId: "org-123",
            organizationName: "Acme",
            planName: "MAX"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try encoder.encode(snapshot)
        let decoded = try decoder.decode(UsageSnapshot.self, from: data)

        XCTAssertEqual(decoded, snapshot)
    }

    func testUnknownWindowKindDecodesGracefully() throws {
        struct Wrapper: Decodable { let kind: UsageWindowKind }
        let json = #"{"kind": "some_future_window"}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(Wrapper.self, from: json)
        XCTAssertEqual(decoded.kind, .unknown("some_future_window"))
    }

    func testBindingWindowPicksHighestUtilization() {
        let snapshot = UsageSnapshot(
            windows: [
                WindowUsage(kind: .fiveHour, utilization: 0.3, resetsAt: nil),
                WindowUsage(kind: .sevenDay, utilization: 0.9, resetsAt: nil)
            ],
            fetchedAt: Date(),
            organizationId: "org-123"
        )
        XCTAssertEqual(snapshot.bindingWindow?.kind, .sevenDay)
    }

    func testIsStale() {
        let snapshot = UsageSnapshot(
            windows: [],
            fetchedAt: Date(timeIntervalSinceNow: -3600),
            organizationId: "org-123"
        )
        XCTAssertTrue(snapshot.isStale(after: 60))
        XCTAssertFalse(snapshot.isStale(after: 7200))
    }
}
