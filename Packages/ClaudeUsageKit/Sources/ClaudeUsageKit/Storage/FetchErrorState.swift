import Foundation

/// Persisted alongside the snapshot so the widget — which never makes
/// network calls itself — can render a "sign in again" / "stale" state
/// without any live auth of its own.
public enum FetchErrorState: String, Codable, Equatable {
    case none
    case sessionExpired
    case network
    case schemaMismatch
    case unknown

    public var userMessage: String? {
        switch self {
        case .none: return nil
        case .sessionExpired: return "Sign in again"
        case .network: return "Couldn't reach Claude — showing last known usage"
        case .schemaMismatch: return "Claude's usage data changed format — this app needs an update"
        case .unknown: return "Something went wrong fetching usage"
        }
    }
}
