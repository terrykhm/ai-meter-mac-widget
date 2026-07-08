# Claude Usage

A native macOS menu bar app + desktop widget that signs into your personal
Claude.ai account and shows your usage/limit status (session % used,
messages used, time until reset).

> Status: source is fully scaffolded; a few Mac-only setup steps are still
> required before it builds and runs. See "Setup" below.

## Disclosure — please read before using

Claude.ai does not publish an official API for your personal plan's
usage/limit numbers (the ones shown in claude.ai's own UI). This app gets
them the same way several existing open-source browser extensions do
(`claude-counter`, `Claude-Usage-Extension`, `claude-usage-tracker`): by
calling an **undocumented internal endpoint** using your own logged-in
session cookie (`sessionKey`), the same way the claude.ai web app itself
does after you sign in in a browser.

Implications:
- This could stop working at any time if Anthropic changes how that
  endpoint works — there's no SLA or stability guarantee on it.
- Your session cookie is stored locally in the macOS Keychain, scoped to
  this app, and is only ever sent to `claude.ai` itself. It is never sent
  anywhere else.
- This is intended for personal, read-only use — checking your own account
  status, not sending messages or accessing anyone else's data.

If you'd rather not rely on this, an official alternative exists for
API/organization billing usage (not personal Pro/Max plan limits): the
[Anthropic Usage & Cost / Rate Limits Admin API](https://platform.claude.com/docs/en/manage-claude/usage-cost-api),
which requires an Admin API key from an API organization.

## What's in this repo

- `Packages/ClaudeUsageKit/` — shared, UI-free Swift package: usage data
  models, the (unofficial) networking client, App-Group-backed shared
  storage, and the polling coordinator. Used by both targets below.
- `App/ClaudeUsageMenuBar/` — the menu bar app: sign-in flow, popover UI,
  settings.
- `Widget/ClaudeUsageWidgetExtension/` — the WidgetKit extension (Small +
  Medium sizes) that reads the latest snapshot the app wrote.
- `project.yml` — [XcodeGen](https://github.com/yonaskolb/XcodeGen) manifest.
  The `.xcodeproj` itself is not committed; you generate it locally.

## Setup

### 1. Prerequisites

- Xcode + Command Line Tools installed.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- An Apple Developer account (free tier is enough for local, personal use)
  to get a Team ID for code signing.

### 2. Fill in the placeholders

Two tokens are used as placeholders throughout the repo and must be
replaced with real values, **consistently, everywhere they appear**:

| Placeholder | Replace with |
|---|---|
| `REPLACE_ME_BUNDLE_PREFIX` | Your reverse-DNS prefix, e.g. `com.yourname` |
| `REPLACE_ME_TEAM_ID` | Your Apple Developer Team ID (Xcode → Settings → Accounts) |

They appear in:
- `project.yml`
- `App/ClaudeUsageMenuBar/ClaudeUsageMenuBar.entitlements`
- `Widget/ClaudeUsageWidgetExtension/ClaudeUsageWidgetExtension.entitlements`
- `Packages/ClaudeUsageKit/Sources/ClaudeUsageKit/Storage/AppGroupConstants.swift`

The App Group identifier in particular (`group.<prefix>.claudeusage`) must
be **identical** in all four locations, or the app and widget won't be able
to share data.

A quick way to do the replacement from the repo root:

```sh
grep -rl 'REPLACE_ME_BUNDLE_PREFIX' . --include='*.yml' --include='*.entitlements' --include='*.swift' \
  | xargs sed -i '' 's/REPLACE_ME_BUNDLE_PREFIX/com.yourname/g'
grep -rl 'REPLACE_ME_TEAM_ID' . --include='*.yml' \
  | xargs sed -i '' 's/REPLACE_ME_TEAM_ID/YOUR_TEAM_ID/g'
```

### 3. Generate and open the Xcode project

```sh
xcodegen generate
open ClaudeUsage.xcodeproj
```

In Xcode, for **both** targets (`ClaudeUsageMenuBar` and
`ClaudeUsageWidgetExtension`):
- Signing & Capabilities → select your Team.
- Add capability "App Groups" → check the same
  `group.<prefix>.claudeusage` group on both targets.
- On `ClaudeUsageMenuBar` only, add capability "Keychain Sharing" with the
  access group matching `ClaudeUsageMenuBar.entitlements`.

Build and run (`ClaudeUsageMenuBar` scheme).

### 4. One-time: capture the real usage endpoint

The exact undocumented claude.ai endpoint this app calls needs to be
captured from a live, logged-in browser session — see
[`Docs/ENDPOINT_NOTES.md`](Docs/ENDPOINT_NOTES.md) for how, and fill in
`ClaudeUsageEndpoints.swift` / `ClaudeUsageAPIClient.swift` to match once you
have it.

Note: `Assets.xcassets` ships with empty `AppIcon`/`MenuBarGlyph` slots
(just the `Contents.json` catalog entries) — drop your own images in when
you're ready; the app builds and runs fine without them in the meantime.

### 5. Add the widget

Open Notification Center (or your desktop) → "Edit Widgets" → search
"Claude Usage" → add the Small or Medium size.

## Troubleshooting

**Sign-in gets stuck / shows a Cloudflare challenge page.** The embedded
in-app browser can occasionally be challenged differently than Safari. Use
the "Enter session key manually" option on the sign-in screen instead: log
into claude.ai in your normal browser, open Web Inspector → Application →
Cookies → `https://claude.ai`, copy the `sessionKey` value, and paste it in.

**Widget shows stale data.** The widget only reads what the app last wrote;
it never fetches on its own. Open the app to trigger a refresh.

**"Sign in again" appears out of nowhere.** Your claude.ai session expired
or was invalidated (e.g. you signed out elsewhere). Sign in again from the
popover.

## License

MIT — see [LICENSE](LICENSE).
