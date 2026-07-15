import Foundation

/// Everything needed to authenticate a request to claude.ai's internal API
/// as the signed-in user. Deliberately just data — reading/writing this
/// from Keychain is the app target's job, never the shared package's.
public struct ClaudeSessionCredentials: Codable, Equatable {
    public let sessionKey: String
    public let organizationId: String

    public init(sessionKey: String, organizationId: String) {
        self.sessionKey = sessionKey
        self.organizationId = organizationId
    }
}
