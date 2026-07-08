import Foundation

/// Typed errors from `ClaudeUsageClient` implementations. Named for the
/// most common failure mode (the undocumented endpoint's response shape
/// drifting), but also covers the auth/transport failures that need
/// distinct UI treatment.
public enum ClaudeUsageDecodingError: Error, Equatable {
    case unauthorized
    case organizationNotFound
    case schemaMismatch(String)
    case rateLimited
    case transport(String)

    public var fetchErrorState: FetchErrorState {
        switch self {
        case .unauthorized: return .sessionExpired
        case .organizationNotFound: return .unknown
        case .schemaMismatch: return .schemaMismatch
        case .rateLimited: return .network
        case .transport: return .network
        }
    }
}
