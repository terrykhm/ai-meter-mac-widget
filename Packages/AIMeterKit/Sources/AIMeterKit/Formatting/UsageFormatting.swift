import Foundation

/// Shared formatting so the popover and both widget faces render numbers
/// identically.
public enum UsageFormatting {
    public static func percentString(_ usage: WindowUsage) -> String {
        "\(usage.percentInt)%"
    }

    public static func usedOfLimitString(_ usage: WindowUsage) -> String? {
        guard let used = usage.used, let limit = usage.limit else { return nil }
        return "\(used) of \(limit) messages"
    }

    public static func resetsInString(_ usage: WindowUsage, referenceDate: Date = Date()) -> String? {
        guard let resetsAt = usage.resetsAt else { return nil }
        let interval = resetsAt.timeIntervalSince(referenceDate)
        guard interval > 0 else { return "Resetting…" }
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 {
            return "Resets in \(hours)h \(minutes)m"
        } else {
            return "Resets in \(minutes)m"
        }
    }

    public static func creditSpentString(amount: Double, currency: String?) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency ?? "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? String(format: "$%.2f", amount)
    }

    public static func lastUpdatedString(_ snapshot: UsageSnapshot, referenceDate: Date = Date()) -> String {
        let interval = referenceDate.timeIntervalSince(snapshot.fetchedAt)
        if interval < 60 {
            return "Updated just now"
        }
        let minutes = Int(interval) / 60
        if minutes < 60 {
            return "Updated \(minutes)m ago"
        }
        let hours = minutes / 60
        return "Updated \(hours)h ago"
    }
}
