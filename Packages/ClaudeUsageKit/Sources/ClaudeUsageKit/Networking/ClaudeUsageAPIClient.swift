import Foundation

/// Concrete `URLSession`-backed implementation of `ClaudeUsageClient`.
///
/// This talks to claude.ai's undocumented internal API using the same
/// `sessionKey` / `lastActiveOrg` cookies a browser sends after a normal
/// login (the same technique used by several existing open-source browser
/// extensions that already do this kind of usage tracking). The exact
/// response shape is UNVERIFIED pending a real capture — see
/// `Docs/ENDPOINT_NOTES.md` — so all parsing is isolated in the DTOs and
/// `map...` function below, to keep a future schema fix contained to this
/// one file.
public final class ClaudeUsageAPIClient: ClaudeUsageClient {
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
        let request = makeRequest(url: ClaudeUsageEndpoints.organizations(), credentials: credentials)
        let (data, response) = try await session.data(for: request)
        try Self.validate(response)
        do {
            let dtos = try Self.makeDecoder().decode([OrganizationDTO].self, from: data)
            return dtos.map { AccountOrganization(id: $0.uuid, name: $0.name) }
        } catch {
            throw ClaudeUsageDecodingError.schemaMismatch("organizations: \(error)")
        }
    }

    public func fetchUsageSnapshot(credentials: ClaudeSessionCredentials, organizationId: String) async throws -> UsageSnapshot {
        let request = makeRequest(url: ClaudeUsageEndpoints.usage(organizationId: organizationId), credentials: credentials)
        let (data, response) = try await session.data(for: request)
        try Self.validate(response)
        do {
            let dto = try Self.makeDecoder().decode(UsageResponseDTO.self, from: data)
            return Self.map(dto, organizationId: organizationId)
        } catch let error as ClaudeUsageDecodingError {
            throw error
        } catch {
            throw ClaudeUsageDecodingError.schemaMismatch("usage: \(error)")
        }
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
            throw ClaudeUsageDecodingError.transport("non-HTTP response")
        }
        switch http.statusCode {
        case 200..<300:
            return
        case 401, 403:
            throw ClaudeUsageDecodingError.unauthorized
        case 404:
            throw ClaudeUsageDecodingError.organizationNotFound
        case 429:
            throw ClaudeUsageDecodingError.rateLimited
        default:
            throw ClaudeUsageDecodingError.transport("HTTP \(http.statusCode)")
        }
    }

    // MARK: - DTO mapping (schema unverified — see Docs/ENDPOINT_NOTES.md)

    private static func map(_ dto: UsageResponseDTO, organizationId: String) -> UsageSnapshot {
        let windows = dto.windows.map { window in
            WindowUsage(
                kind: UsageWindowKind(rawValue: window.kind),
                utilization: window.utilization,
                resetsAt: window.resetsAt,
                used: window.used,
                limit: window.limit
            )
        }
        return UsageSnapshot(
            windows: windows,
            fetchedAt: Date(),
            organizationId: organizationId,
            organizationName: dto.organizationName,
            planName: dto.planName
        )
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

// MARK: - DTOs (placeholder shape pending real capture, see Docs/ENDPOINT_NOTES.md)

private struct OrganizationDTO: Decodable {
    let uuid: String
    let name: String?
}

private struct UsageResponseDTO: Decodable {
    let organizationName: String?
    let planName: String?
    let windows: [WindowDTO]

    struct WindowDTO: Decodable {
        let kind: String
        let utilization: Double
        let resetsAt: Date?
        let used: Int?
        let limit: Int?
    }
}
