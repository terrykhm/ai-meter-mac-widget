import Foundation

/// A point-in-time snapshot of the signed-in account's usage across all
/// tracked windows. This is the value the app fetches, writes to the App
/// Group container, and the widget reads back — it never touches the
/// network or Keychain itself.
public struct UsageSnapshot: Codable, Equatable {
    public let windows: [WindowUsage]
    public let fetchedAt: Date
    public let organizationId: String
    public let organizationName: String?
    public let planName: String?
    /// Whether the account has Usage Credits (pay-per-use billing) enabled.
    public let usageCreditEnabled: Bool
    /// Total dollars spent via Usage Credits in the current billing period.
    public let usageCreditSpent: Double?
    /// ISO 4217 currency code for `usageCreditSpent` (e.g. "USD").
    public let usageCreditCurrency: String?

    public init(
        windows: [WindowUsage],
        fetchedAt: Date,
        organizationId: String,
        organizationName: String? = nil,
        planName: String? = nil,
        usageCreditEnabled: Bool = false,
        usageCreditSpent: Double? = nil,
        usageCreditCurrency: String? = nil
    ) {
        self.windows = windows
        self.fetchedAt = fetchedAt
        self.organizationId = organizationId
        self.organizationName = organizationName
        self.planName = planName
        self.usageCreditEnabled = usageCreditEnabled
        self.usageCreditSpent = usageCreditSpent
        self.usageCreditCurrency = usageCreditCurrency
    }

    /// The window with the highest utilization — mirrors Anthropic's own
    /// `anthropic-ratelimit-unified-representative-claim` idea of surfacing
    /// whichever window is currently the binding constraint.
    public var bindingWindow: WindowUsage? {
        windows.max(by: { $0.utilization < $1.utilization })
    }

    public var fiveHourWindow: WindowUsage? {
        windows.first { $0.kind == .fiveHour }
    }

    public var sevenDayWindow: WindowUsage? {
        windows.first { $0.kind == .sevenDay }
    }

    public func isStale(after interval: TimeInterval, referenceDate: Date = Date()) -> Bool {
        referenceDate.timeIntervalSince(fetchedAt) > interval
    }
}
