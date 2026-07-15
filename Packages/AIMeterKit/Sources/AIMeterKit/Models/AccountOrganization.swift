import Foundation

/// A claude.ai organization/account the signed-in session belongs to.
/// Personal accounts have exactly one; Team/Enterprise-style accounts may
/// have several, in which case the user picks one to track.
public struct AccountOrganization: Codable, Equatable, Identifiable {
    public let id: String
    public let name: String?

    public init(id: String, name: String?) {
        self.id = id
        self.name = name
    }
}
