import Foundation

/// Abstraction over "fetch this account's usage data from claude.ai".
/// Kept as a protocol specifically so the fragile, unofficial parsing
/// logic in `ClaudeUsageAPIClient` is swappable/fixable in isolation, and
/// so tests/previews can substitute a fake implementation.
public protocol ClaudeUsageClient {
    func fetchOrganizations(credentials: ClaudeSessionCredentials) async throws -> [AccountOrganization]
    func fetchUsageSnapshot(credentials: ClaudeSessionCredentials, organizationId: String) async throws -> UsageSnapshot
}
