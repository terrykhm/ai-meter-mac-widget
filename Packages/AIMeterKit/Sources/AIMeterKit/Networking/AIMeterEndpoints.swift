import Foundation

/// Endpoint builders for claude.ai's UNDOCUMENTED internal API.
///
/// Both paths below were confirmed against a real, logged-in claude.ai
/// session (Settings → Usage triggers the `usage` request) — see
/// `Docs/ENDPOINT_NOTES.md` for the captured request/response.
public enum AIMeterEndpoints {
    public static let baseURL = URL(string: "https://claude.ai")!

    /// Lists organizations the signed-in account belongs to. Used to
    /// resolve `organizationId` when it isn't already known from the
    /// `lastActiveOrg` cookie. Note a single account can belong to more
    /// than one organization (e.g. a separate API/console org) — the
    /// caller picks the first one, which in practice is the claude.ai
    /// chat org.
    public static func organizations() -> URL {
        baseURL.appendingPathComponent("api/organizations")
    }

    /// Confirmed path — same one claude.ai's own Settings → Usage panel
    /// calls (`GET /api/organizations/{organizationId}/usage`).
    public static func usage(organizationId: String) -> URL {
        baseURL.appendingPathComponent("api/organizations/\(organizationId)/usage")
    }
}
