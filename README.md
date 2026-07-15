# AI Meter

A native macOS background app + desktop widget for tracking AI usage.
Currently supports Claude.ai only: it signs into your personal account and
shows your usage/limit status (session % used, time until reset) via its
desktop widget. Built to grow into other providers (Gemini, ChatGPT, ...)
over time — the widget's "AI Meter" header sits above the current
Claude-specific content for that reason.

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

- `Packages/AIMeterKit/` — shared, UI-free Swift package: usage data
  models, the (unofficial) networking client, shared-file-backed storage,
  and the polling coordinator. Used by both targets below.
- `App/AIMeterMenuBar/` — the menu bar app: sign-in flow, popover UI,
  settings.
- `Widget/AIMeterWidgetExtension/` — the WidgetKit extension (Small +
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
  plain file (`~/Library/Application Support/AIMeter/`) instead of an
  App Group: Apple restricts the App Groups capability to paid accounts,
  and this app deliberately avoids needing it. The widget extension
  target is still App-Sandboxed — macOS requires that for a WidgetKit
  extension to register with `pluginkitd` at all (an unsandboxed widget
  builds and embeds fine but silently never appears in the widget
  gallery) — it just reaches the shared file via a
  `com.apple.security.temporary-exception.files.home-relative-path.read-write`
  entitlement instead of an App Group container. See
  `Widget/AIMeterWidgetExtension/AIMeterWidgetExtension.entitlements`.
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
open AIMeter.xcodeproj
```

In Xcode, for **both** targets (`AIMeterMenuBar` and
`AIMeterWidgetExtension`), confirm Signing & Capabilities shows your
Team selected (it should already be filled in from `DEVELOPMENT_TEAM` in
`project.yml`) with no red errors. No other capabilities need adding —
there's no App Group or Keychain Sharing group to configure.

Build and run (`AIMeterMenuBar` scheme). To confirm signing actually
took (not just that Xcode shows no error), you can check from Terminal
after building:

```sh
codesign -dvv /path/to/AIMeterMenuBar.app 2>&1 | grep TeamIdentifier
codesign -dvv /path/to/AIMeterMenuBar.app/Contents/PlugIns/AIMeterWidgetExtension.appex 2>&1 | grep TeamIdentifier
```

Both should print your real Team ID (not "not set") — if either shows
"not set", the app/extension is only ad-hoc signed and the widget will
never register with the system (`pluginkit -m -v -p
com.apple.widgetkit-extension` will print nothing for it).

### 4. One-time: capture the real usage endpoint

The exact undocumented claude.ai endpoint this app calls needs to be
captured from a live, logged-in browser session — see
[`Docs/ENDPOINT_NOTES.md`](Docs/ENDPOINT_NOTES.md) for how, and fill in
`AIMeterEndpoints.swift` / `AIMeterAPIClient.swift` to match once you
have it.

### 5. Add the widget

Open Notification Center (or your desktop) → "Edit Widgets" → search
"AI Meter" → add the Small, Medium, or Large size.

### 6. Distribution builds (notarized)

Steps 1–5 above are for local development (Debug config, free-tier
"Apple Development" signing). Release builds — the ones published on
[GitHub Releases](https://github.com/terrykhm/ai-meter-mac-widget/releases/latest) —
are signed with a paid "Developer ID Application" certificate and
notarized by Apple, so Gatekeeper accepts them with no warnings at all
on any Mac, not just the one that built them. That needs a paid Apple
Developer Program membership on this Team ID, plus:

```sh
# One-time: generate a Developer ID Application certificate via
# Xcode → Settings → Accounts → Manage Certificates → + → Developer ID
# Application. And store notarization credentials (prompts for an
# app-specific password from appleid.apple.com, not your Apple ID
# password):
xcrun notarytool store-credentials "AC_PASSWORD" --apple-id "you@example.com" --team-id "YOUR_TEAM_ID"

# Every release: archive, export, notarize, staple.
xcodebuild archive -project AIMeter.xcodeproj -scheme AIMeterMenuBar -configuration Release -archivePath /tmp/AIMeter.xcarchive
xcodebuild -exportArchive -archivePath /tmp/AIMeter.xcarchive -exportPath /tmp/AIMeter-export -exportOptionsPlist ExportOptions.plist
ditto -c -k --keepParent /tmp/AIMeter-export/AIMeterMenuBar.app /tmp/AIMeter-notarize.zip
xcrun notarytool submit /tmp/AIMeter-notarize.zip --keychain-profile "AC_PASSWORD" --wait
xcrun stapler staple /tmp/AIMeter-export/AIMeterMenuBar.app
```

`ExportOptions.plist` needs `method: developer-id`, your `teamID`, and
`signingCertificate: "Developer ID Application"` — it's not committed to
this repo (nothing sensitive in it, just not needed by anyone building
Debug-only). A plain `xcodebuild build` (rather than `archive` +
`-exportArchive`) will *not* produce a notarizable build even in
Release config — it always includes the `get-task-allow` debug
entitlement and skips secure timestamping, both of which notarization
rejects.

## Installing on another Mac

Every [GitHub Release](https://github.com/terrykhm/ai-meter-mac-widget/releases/latest)
is signed and notarized by Apple, so it just opens normally — no
Gatekeeper warnings, no "unidentified developer" dialogs, no developer
account needed on the installing machine.

- **Recommended: unzip and drag the app into /Applications yourself.**
  Download `AI-Meter.zip` from the
  [releases page](https://github.com/terrykhm/ai-meter-mac-widget/releases/latest),
  double-click it in Finder to unzip, then drag `AIMeterMenuBar.app`
  into Applications. Dragging via Finder (rather than launching it
  in-place from wherever it unzipped) avoids macOS's App Translocation,
  which otherwise runs a freshly-downloaded app from a hidden temporary
  path and can make the widget's registration disappear after a reboot.
- **Alternative: paste this into Terminal** if you'd rather not touch
  Finder:
  ```sh
  curl -fsSL -o /tmp/AIMeter.zip https://github.com/terrykhm/ai-meter-mac-widget/releases/latest/download/AI-Meter.zip && \
  ditto -x -k /tmp/AIMeter.zip /tmp/AIMeter-extracted && \
  xattr -cr /tmp/AIMeter-extracted/AIMeterMenuBar.app && \
  rm -rf /Applications/AIMeterMenuBar.app && \
  mv /tmp/AIMeter-extracted/AIMeterMenuBar.app /Applications/ && \
  open /Applications/AIMeterMenuBar.app && \
  rm -rf /tmp/AIMeter-extracted /tmp/AIMeter.zip
  ```
  This always grabs whatever the latest release is, so it doesn't go
  stale as new versions ship.
- **Alternative: clone and build on each Mac** (Setup steps 1–3) if you'd
  rather build from source than trust a prebuilt binary.

Any of these is a one-time step per Mac. The widget should self-register
with `pluginkitd` automatically; if it doesn't show up in the widget
gallery, re-run the `pluginkit -a` step from Troubleshooting below.

Releases are point-in-time snapshots, not something CI keeps in sync
with source — they'll drift stale after future source changes until a
new one is built and published.

Either way, sign-in and the shared usage snapshot are per-machine — the
Keychain-stored session and the file under `~/Library/Application
Support/AIMeter/` don't sync between Macs, so you'll sign in
separately on each one.

## Troubleshooting

**Sign-in gets stuck / shows a Cloudflare challenge page.** The embedded
in-app browser can occasionally be challenged differently than Safari. Use
the "Enter session key manually" option on the sign-in screen instead: log
into claude.ai in your normal browser, open Web Inspector → Application →
Cookies → `https://claude.ai`, copy the `sessionKey` value, and paste it in.

**Widget shows stale data.** The widget only reads what the app last wrote;
it never fetches on its own. The app has no menu bar icon — reopen it
(double-click `AI Meter.app`/`AIMeterMenuBar.app` again in Finder or
Spotlight while it's already running) to bring up Settings and trigger a
refresh.

**"Sign in again" appears out of nowhere.** Your claude.ai session expired
or was invalidated (e.g. you signed out elsewhere). Reopen the app and sign
in again from Settings.

**Widget doesn't show up in "Edit Widgets" at all.** macOS silently
refuses to register an unsandboxed WidgetKit extension with `pluginkitd` —
no error anywhere, it just never appears. If you've confirmed both targets
are actually signed with your real Team ID (step 3 above) and it's still
missing, force a re-scan:

```sh
pluginkit -a /path/to/AIMeterMenuBar.app/Contents/PlugIns/AIMeterWidgetExtension.appex
pluginkit -m -v -p com.apple.widgetkit-extension | grep -i aimeter
```

The second command should print a line for `com.terrykhm.aimeter.widget`
(or your own bundle prefix). If it still prints nothing, check
`Widget/AIMeterWidgetExtension/AIMeterWidgetExtension.entitlements`
exists and is wired up via `CODE_SIGN_ENTITLEMENTS` in `project.yml` — the
widget target must have App Sandbox enabled for registration to work at
all, even though the main app deliberately isn't sandboxed.

**Widget worked, then disappeared after a reboot (only on a downloaded
copy, not one built from source).** The app likely got run via macOS's
App Translocation — launched from a hidden randomized path instead of
/Applications, which happens when a quarantined app is opened without
its quarantine flag ever being cleared or without being dragged into
/Applications through Finder. That temporary path doesn't survive a
reboot, so the widget's registration silently breaks. Fix: quit the
app, delete it, and reinstall by dragging it into /Applications from
Finder rather than running it in place — check `ps aux | grep
AIMeterMenuBar` for a path containing `AppTranslocation` to confirm
this is what happened.

## License

MIT — see [LICENSE](LICENSE).
