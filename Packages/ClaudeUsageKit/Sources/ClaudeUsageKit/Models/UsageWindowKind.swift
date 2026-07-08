import Foundation

/// The rate-limit "windows" Anthropic tracks usage against. Mirrors the
/// `five_hour` / `seven_day` / `seven_day_opus` / `seven_day_sonnet` window
/// names observed on `anthropic-ratelimit-unified-*` response headers.
/// `.unknown` is the forward-compat fallback for any window name we don't
/// recognize yet, so a schema addition on Anthropic's side decodes instead
/// of throwing.
public enum UsageWindowKind: Codable, Equatable, Hashable {
    case fiveHour
    case sevenDay
    case sevenDayOpus
    case sevenDaySonnet
    case unknown(String)

    public var rawValue: String {
        switch self {
        case .fiveHour: return "five_hour"
        case .sevenDay: return "seven_day"
        case .sevenDayOpus: return "seven_day_opus"
        case .sevenDaySonnet: return "seven_day_sonnet"
        case .unknown(let value): return value
        }
    }

    public init(rawValue: String) {
        switch rawValue {
        case "five_hour": self = .fiveHour
        case "seven_day": self = .sevenDay
        case "seven_day_opus": self = .sevenDayOpus
        case "seven_day_sonnet": self = .sevenDaySonnet
        default: self = .unknown(rawValue)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self.init(rawValue: rawValue)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var displayName: String {
        switch self {
        case .fiveHour: return "Session"
        case .sevenDay: return "Weekly"
        case .sevenDayOpus: return "Weekly (Opus)"
        case .sevenDaySonnet: return "Weekly (Sonnet)"
        case .unknown(let value): return value
        }
    }
}
