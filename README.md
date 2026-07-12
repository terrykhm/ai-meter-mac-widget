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
  models, the (unofficial) networking client, shared-file-backed storage,
  and the polling coordinator. Used by both targets below.
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
- An Apple ID signed into Xcode (Xcode → Settings → Accounts). A free
  "Personal Team" is enough — no paid Apple Developer Program membership
  needed. That's exactly why the app and widget share data through a
  plain file (`~/Library/Application Support/ClaudeUsage/`) instead of an
  App Group: Apple restricts the App Groups capability to paid accounts,
  and this app deliberately avoids needing it. The widget extension
  target is still App-Sandboxed — macOS requires that for a WidgetKit
  extension to register with `pluginkitd` at all (an unsandboxed widget
  builds and embeds fine but silently never appears in the widget
  gallery) — it just reaches the shared file via a
  `com.apple.security.temporary-exception.files.home-relative-path.read-write`
  entitlement instead of an App Group container. See
  `Widget/ClaudeUsageWidgetExtension/ClaudeUsageWidgetExtension.entitlements`.
  The main menu bar app target is not sandboxed.

### 2. Bundle identifier and Team ID

`project.yml`'s `bundleIdPrefix` and `PRODUCT_BUNDLE_IDENTIFIER` values
are already set to this repo owner's real reverse-DNS prefix
(`com.terrykhm`) — if you're building this for yourself from this repo,
you can leave it as-is, or replace it with your own prefix if you'd
rather use a different one:

```sh
sed -i '' 's/com\.terrykhm/com.yourname/g' project.yml
```

`project.yml` also sets `DEVELOPMENT_TEAM` explicitly for both targets
(already filled in with this repo owner's real Team ID). If you're
building for yourself, replace that value with your own Team ID too, not
just the bundle prefix. This matters even though signing is otherwise on
Automatic: `xcodegen generate` regenerates the `.xcodeproj` from this
file every time, which silently wipes out any Team you select only in
Xcode's Signing & Capabilities UI — setting it here is what makes it
stick across regenerations.

To find your own Team ID (works for a free Personal Team too, not just
paid memberships): first select your Personal Team once in Xcode's
Signing & Capabilities for either target (this makes Xcode create a
local signing certificate if you don't have one yet), then open
**Keychain Access** → login keychain → **My Certificates** → find the
certificate named something like "Apple Development: you@example.com" →
double-click it → the **Organizational Unit** field is your Team ID.

### 3. Generate and open the Xcode project

```sh
xcodegen generate
open ClaudeUsage.xcodeproj
```

In Xcode, for **both** targets (`ClaudeUsageMenuBar` and
`ClaudeUsageWidgetExtension`), confirm Signing & Capabilities shows your
Team selected (it should already be filled in from `DEVELOPMENT_TEAM` in
`project.yml`) with no red errors. No other capabilities need adding —
there's no App Group or Keychain Sharing group to configure.

Build and run (`ClaudeUsageMenuBar` scheme). To confirm signing actually
took (not just that Xcode shows no error), you can check from Terminal
after building:

```sh
codesign -dvv /path/to/ClaudeUsageMenuBar.app 2>&1 | grep TeamIdentifier
codesign -dvv /path/to/ClaudeUsageMenuBar.app/Contents/PlugIns/ClaudeUsageWidgetExtension.appex 2>&1 | grep TeamIdentifier
```

Both should print your real Team ID (not "not set") — if either shows
"not set", the app/extension is only ad-hoc signed and the widget will
never register with the system (`pluginkit -m -v -p
com.apple.widgetkit-extension` will print nothing for it).

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
