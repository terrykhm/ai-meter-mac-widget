import Foundation

/// Usage/limit status for a single rate-limit window (e.g. the current
/// 5-hour session, or the current 7-day week).
public struct WindowUsage: Codable, Equatable, Identifiable {
    public var id: String { kind.rawValue }

    public let kind: UsageWindowKind
    /// 0.0...1.0
    public let utilization: Double
    public let resetsAt: Date?
    public let used: Int?
    public let limit: Int?

    public init(kind: UsageWindowKind, utilization: Double, resetsAt: Date?, used: Int? = nil, limit: Int? = nil) {
        self.kind = kind
        self.utilization = min(max(utilization, 0), 1)
        self.resetsAt = resetsAt
        self.used = used
        self.limit = limit
    }

    public var percentInt: Int {
        Int((utilization * 100).rounded())
    }

    public var isNearLimit: Bool {
        utilization >= 0.85
    }
}
