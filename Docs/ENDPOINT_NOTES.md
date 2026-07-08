# Endpoint capture notes

`ClaudeUsageEndpoints.swift` and `ClaudeUsageAPIClient.swift` target an
**undocumented** claude.ai internal API. The exact request/response shape
needs to be captured from a real, logged-in browser session before those two
files can be finished — this can't be done from this environment.

## How to capture it

1. In Safari (or Chrome), log into <https://claude.ai> normally.
2. Open Web Inspector → Network tab, filter to XHR/fetch.
3. Open a conversation (or trigger the usage banner claude.ai shows near your
   plan limit) and look for a request whose response contains fields like
   utilization percentages and reset timestamps — candidates seen in prior
   art (community browser extensions) include a `/usage`-style endpoint keyed
   off your active organization. Also check the response headers of the
   chat-send request itself for `anthropic-ratelimit-unified-*` headers.
4. Record below: exact request URL (with placeholders for your org id),
   required headers/cookies, and the full JSON response body (redact your
   real session token / personal data before pasting here).

## Captured request

```
(paste method + URL here)
```

## Required headers / cookies

```
(paste here — expect Cookie: sessionKey=...; lastActiveOrg=...)
```

## Response JSON shape

```json
(paste a redacted sample response here)
```

## Mapping notes

Once the shape above is filled in, update:
- `Packages/ClaudeUsageKit/Sources/ClaudeUsageKit/Networking/ClaudeUsageEndpoints.swift` — the real path.
- `Packages/ClaudeUsageKit/Sources/ClaudeUsageKit/Networking/ClaudeUsageAPIClient.swift` — the DTO struct and its mapping into `UsageSnapshot`.
- `Packages/ClaudeUsageKit/Tests/ClaudeUsageKitTests/ClaudeUsageAPIClientTests.swift` — add a fixture-based test using the (redacted) sample response.
