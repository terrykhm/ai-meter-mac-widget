import Foundation

/// Endpoint builders for claude.ai's UNDOCUMENTED internal API.
///
/// TODO(schema-verification): none of the paths below have been confirmed
/// against a real, live claude.ai session — Claude Code cannot browse an
/// authenticated claude.ai session from its own environment. Capture the
/// real requests per `Docs/ENDPOINT_NOTES.md` (Safari Web Inspector while
/// logged in) and update these before relying on them.
public enum ClaudeUsageEndpoints {
    public static let baseURL = URL(string: "https://claude.ai")!

    /// Lists organizations the signed-in account belongs to. Used to
    /// resolve `organizationId` when it isn't already known from the
    /// `lastActiveOrg` cookie.
    public static func organizations() -> URL {
        baseURL.appendingPathComponent("api/organizations")
    }

    /// TODO(schema-verification): placeholder path. Prior art (community
    /// browser extensions that already do this kind of tracking) points at
    /// an endpoint scoped to the active organization; confirm the exact
    /// path and query parameters from a real capture.
    public static func usage(organizationId: String) -> URL {
        baseURL.appendingPathComponent("api/organizations/\(organizationId)/usage")
    }
}
