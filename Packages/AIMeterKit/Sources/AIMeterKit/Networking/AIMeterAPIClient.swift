import Foundation

/// Concrete `URLSession`-backed implementation of `AIMeterClient`.
///
/// This talks to claude.ai's undocumented internal API using the same
/// `sessionKey` / `lastActiveOrg` cookies a browser sends after a normal
/// login (the same technique used by several existing open-source browser
/// extensions that already do this kind of usage tracking). The response
/// shape was confirmed from a real, logged-in session — see
/// `Docs/ENDPOINT_NOTES.md` — parsing stays isolated in the DTOs and
/// `map...` function below so a future schema drift fix stays contained
/// to this one file.
public final class AIMeterAPIClient: AIMeterClient {
    private let session: URLSession
    private let userAgent: String

    public init(
        session: URLSession = URLSession(configuration: .ephemeral),
        userAgent: String = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
    ) {
        self.session = session
        self.userAgent = userAgent
    }

    public func fetchOrganizations(credentials: ClaudeSessionCredentials) async throws -> [AccountOrganization] {
        let request = makeRequest(url: AIMeterEndpoints.organizations(), credentials: credentials)
        let (data, response) = try await session.data(for: request)
        try Self.validate(response)
        do {
            let dtos = try Self.makeDecoder().decode([OrganizationDTO].self, from: data)
            return dtos.map { AccountOrganization(id: $0.uuid, name: $0.name) }
        } catch {
            throw AIMeterDecodingError.schemaMismatch("organizations: \(error)")
        }
    }

    public func fetchUsageSnapshot(credentials: ClaudeSessionCredentials, organizationId: String) async throws -> UsageSnapshot {
        let request = makeRequest(url: AIMeterEndpoints.usage(organizationId: organizationId), credentials: credentials)
        let (data, response) = try await session.data(for: request)
        try Self.validate(response)
        let dto: UsageResponseDTO
        do {
            dto = try Self.makeDecoder().decode(UsageResponseDTO.self, from: data)
        } catch {
            throw AIMeterDecodingError.schemaMismatch("usage: \(error)")
        }
        // The usage endpoint itself carries no plan info; best-effort only
        // — a failure here shouldn't fail the usage fetch, the badge just
        // won't show for that cycle.
        let planName = try? await fetchPlanLabel(credentials: credentials, organizationId: organizationId)
        return Self.map(dto, organizationId: organizationId, planName: planName)
    }

    /// Re-fetches `/api/organizations` to read `capabilities` for the
    /// active org and derive a short plan badge from it (e.g.
    /// `"claude_pro"` -> "PRO"). The mapping below is inferred from a
    /// single real Pro-plan capture — see Docs/ENDPOINT_NOTES.md — so it's
    /// necessarily a guess for other tiers; unrecognized capability sets
    /// just mean no badge rather than a wrong one.
    private func fetchPlanLabel(credentials: ClaudeSessionCredentials, organizationId: String) async throws -> String? {
        let request = makeRequest(url: AIMeterEndpoints.organizations(), credentials: credentials)
        let (data, response) = try await session.data(for: request)
        try Self.validate(response)
        let dtos = try Self.makeDecoder().decode([OrganizationDTO].self, from: data)
        guard let match = dtos.first(where: { $0.uuid == organizationId }) else { return nil }
        return Self.planLabel(from: match.capabilities ?? [])
    }

    private static func planLabel(from capabilities: [String]) -> String? {
        if capabilities.contains("claude_max") { return "MAX" }
        if capabilities.contains("claude_team") { return "TEAM" }
        if capabilities.contains("claude_enterprise") { return "ENTERPRISE" }
        if capabilities.contains("claude_pro") { return "PRO" }
        return nil
    }

    // MARK: - Request building

    private func makeRequest(url: URL, credentials: ClaudeSessionCredentials) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(
            "sessionKey=\(credentials.sessionKey); lastActiveOrg=\(credentials.organizationId)",
            forHTTPHeaderField: "Cookie"
        )
        return request
    }

    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw AIMeterDecodingError.transport("non-HTTP response")
        }
        switch http.statusCode {
        case 200..<300:
            return
        case 401, 403:
            throw AIMeterDecodingError.unauthorized
        case 404:
            throw AIMeterDecodingError.organizationNotFound
        case 429:
            throw AIMeterDecodingError.rateLimited
        default:
            throw AIMeterDecodingError.transport("HTTP \(http.statusCode)")
        }
    }

    // MARK: - DTO mapping (schema confirmed — see Docs/ENDPOINT_NOTES.md)

    private static func map(_ dto: UsageResponseDTO, organizationId: String, planName: String?) -> UsageSnapshot {
        let windows: [WindowUsage] = [
            dto.fiveHour.map { WindowUsage(kind: .fiveHour, utilization: $0.utilization / 100, resetsAt: $0.resetsAt) },
            dto.sevenDay.map { WindowUsage(kind: .sevenDay, utilization: $0.utilization / 100, resetsAt: $0.resetsAt) }
        ].compactMap { $0 }
        let creditEnabled = dto.spend?.enabled ?? false
        let creditSpent = dto.spend?.used.map { Double($0.amountMinor) / pow(10.0, Double($0.exponent)) }
        let creditCurrency = dto.spend?.used?.currency
        return UsageSnapshot(
            windows: windows,
            fetchedAt: Date(),
            organizationId: organizationId,
            planName: planName,
            usageCreditEnabled: creditEnabled,
            usageCreditSpent: creditSpent,
            usageCreditCurrency: creditCurrency
        )
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        let withFractionalSeconds = ISO8601DateFormatter()
        withFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let withoutFractionalSeconds = ISO8601DateFormatter()
        withoutFractionalSeconds.formatOptions = [.withInternetDateTime]
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            if let date = withFractionalSeconds.date(from: dateString) {
                return date
            }
            if let date = withoutFractionalSeconds.date(from: dateString) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unrecognized date format: \(dateString)")
        }
        return decoder
    }
}

// MARK: - DTOs
//
// Only the fields this app actually uses are declared — `Decodable`
// ignores unrecognized keys, so the many other (mostly-null, seemingly
// codenamed) fields in the real response are simply skipped rather than
// causing a decode failure. Confirmed shape, see Docs/ENDPOINT_NOTES.md.

private struct OrganizationDTO: Decodable {
    let uuid: String
    let name: String?
    let capabilities: [String]?
}

/// `GET /api/organizations/{id}/usage`. The real response has no
/// `windows` array, message counts, org name, or plan name — just
/// per-window utilization percentages (0...100, not 0...1) keyed by
/// window name at the top level.
private struct UsageResponseDTO: Decodable {
    let fiveHour: WindowDTO?
    let sevenDay: WindowDTO?
    let spend: SpendDTO?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case spend
    }

    struct WindowDTO: Decodable {
        let utilization: Double
        let resetsAt: Date?

        enum CodingKeys: String, CodingKey {
            case utilization
            case resetsAt = "resets_at"
        }
    }

    struct SpendDTO: Decodable {
        let enabled: Bool
        let used: MoneyDTO?

        struct MoneyDTO: Decodable {
            let amountMinor: Int
            let currency: String
            let exponent: Int

            enum CodingKeys: String, CodingKey {
                case amountMinor = "amount_minor"
                case currency
                case exponent
            }
        }
    }
}
