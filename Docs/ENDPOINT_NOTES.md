# Endpoint capture notes

`AIMeterEndpoints.swift` and `AIMeterAPIClient.swift` target an
**undocumented** claude.ai internal API. The shape below was captured from
a real, logged-in browser session (via the Claude in Chrome MCP driving an
actual signed-in claude.ai tab) and is now what the client code implements.

## How it was captured

1. Logged into claude.ai in Chrome (already-authenticated session).
2. Opened the account menu → **Settings → Usage** — that panel calls the
   exact endpoint this app needs, so no manual conversation/banner-triggering
   was necessary.
3. Read the network request the Usage panel fired, then re-requested the
   same URL directly (cookies carry over within the browser) to capture the
   full raw JSON body.

## Captured request

```
GET https://claude.ai/api/organizations/{organizationId}/usage
```

`{organizationId}` is the account's claude.ai chat org UUID (from
`GET /api/organizations`, or the `lastActiveOrg` cookie set after login —
note an account can have more than one org, e.g. a separate API/console
org; the chat org is the one with `"claude_pro"`/similar in `capabilities`).

## Required headers / cookies

```
Cookie: sessionKey=...; lastActiveOrg=...
Accept: application/json
```

## Response JSON shape

Redacted real response (Pro plan account, all dollar/spend fields null
since this account isn't on metered billing):

```json
{
  "five_hour": {
    "utilization": 40.0,
    "resets_at": "2026-07-12T07:00:00.069688+00:00",
    "limit_dollars": null,
    "used_dollars": null,
    "remaining_dollars": null
  },
  "seven_day": {
    "utilization": 5.0,
    "resets_at": "2026-07-14T06:00:00.069713+00:00",
    "limit_dollars": null,
    "used_dollars": null,
    "remaining_dollars": null
  },
  "seven_day_opus": null,
  "seven_day_sonnet": null,
  "seven_day_oauth_apps": null,
  "extra_usage": { "is_enabled": false, "...": "..." },
  "limits": [
    {
      "kind": "session",
      "group": "session",
      "percent": 40,
      "severity": "normal",
      "resets_at": "2026-07-12T07:00:00.069688+00:00",
      "scope": null,
      "is_active": true
    },
    {
      "kind": "weekly_all",
      "group": "weekly",
      "percent": 5,
      "severity": "normal",
      "resets_at": "2026-07-14T06:00:00.069713+00:00",
      "scope": null,
      "is_active": false
    }
  ],
  "spend": { "enabled": false, "...": "..." },
  "member_dashboard_available": false
}
```

Notable surprises vs. the original placeholder guess:
- No `windows` array, no `organizationName`/`planName`, no message-count
  `used`/`limit` fields at all — this response is percentage-only.
- `utilization` is `0...100`, not `0...1` — the client divides by 100.
- Windows are top-level keys (`five_hour`, `seven_day`, ...), not a list.
- `resets_at` has microsecond fractional seconds and a colon-delimited UTC
  offset (`+00:00`, not `Z`) — `JSONDecoder`'s default `.iso8601` strategy
  rejects this; the client uses a custom `ISO8601DateFormatter` with
  `.withFractionalSeconds` (falling back to without, in case a window ever
  omits the fraction).
- There's also a newer, more general `limits` array (covers per-model
  scoped weekly limits like a `"Fable"` window) that isn't used yet but is
  worth switching to if per-model breakdowns are ever wanted.

## Mapping notes

Implemented in:
- `Packages/AIMeterKit/Sources/AIMeterKit/Networking/AIMeterEndpoints.swift` — confirmed path.
- `Packages/AIMeterKit/Sources/AIMeterKit/Networking/AIMeterAPIClient.swift` — `UsageResponseDTO` (only declares `five_hour`/`seven_day`; unknown keys are ignored by `Decodable`) and its mapping into `UsageSnapshot`.
- `Packages/AIMeterKit/Tests/AIMeterKitTests/AIMeterAPIClientTests.swift` — fixture test using this (redacted) sample response.
