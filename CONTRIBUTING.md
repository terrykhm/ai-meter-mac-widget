# Contributing / building from source

This covers building AI Meter from source, understanding the project
layout, and cutting notarized releases. If you just want to use the app,
see the [README](README.md) instead — none of this is needed for that.

## What's in this repo

- `Packages/AIMeterKit/` — shared, UI-free Swift package: usage data
  models, the (unofficial) networking client, shared-file-backed storage,
  and the polling coordinator. Used by both targets below.
- `App/AIMeterMenuBar/` — the menu bar app: sign-in flow, popover UI,
  settings.
- `Widget/AIMeterWidgetExtension/` — the WidgetKit extension (Small,
  Medium, and Large sizes) that reads the latest snapshot the app wrote.
- `project.yml` — [XcodeGen](https://github.com/yonaskolb/XcodeGen)
  manifest. The `.xcodeproj` itself is not committed; you generate it
  locally.

## 1. Prerequisites

- Xcode + Command Line Tools installed.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- An Apple ID signed into Xcode (Xcode → Settings → Accounts). A free
  "Personal Team" is enough — no paid Apple Developer Program membership
  needed. That's exactly why the app and widget share data through a
  plain file (`~/Library/Application Support/AIMeter/`) instead of an App
  Group: Apple restricts the App Groups capability to paid accounts, and
  this app deliberately avoids needing it. The widget extension target is
  still App-Sandboxed — macOS requires that for a WidgetKit extension to
  register with `pluginkitd` at all (an unsandboxed widget builds and
  embeds fine but silently never appears in the widget gallery) — it just
  reaches the shared file via a
  `com.apple.security.temporary-exception.files.home-relative-path.read-write`
  entitlement instead of an App Group container. See
  `Widget/AIMeterWidgetExtension/AIMeterWidgetExtension.entitlements`. The
  main menu bar app target is not sandboxed.

## 2. Bundle identifier and Team ID

`project.yml`'s `bundleIdPrefix` and `PRODUCT_BUNDLE_IDENTIFIER` values
are already set to this repo owner's real reverse-DNS prefix
(`com.terrykhm`) — if you're building this for yourself, you can leave it
as-is, or replace it with your own prefix:

```sh
sed -i '' 's/com\.terrykhm/com.yourname/g' project.yml
```

`project.yml` also sets `DEVELOPMENT_TEAM` explicitly for both targets
(already filled in with this repo owner's real Team ID). If you're
building for yourself, replace that value with your own Team ID too, not
just the bundle prefix. This matters even though signing is otherwise on
Automatic: `xcodegen generate` regenerates the `.xcodeproj` from this file
every time, which silently wipes out any Team you select only in Xcode's
Signing & Capabilities UI — setting it here is what makes it stick across
regenerations.

To find your own Team ID (works for a free Personal Team too, not just
paid memberships): first select your Personal Team once in Xcode's
Signing & Capabilities for either target (this makes Xcode create a local
signing certificate if you don't have one yet), then open **Keychain
Access** → login keychain → **My Certificates** → find the certificate
named something like "Apple Development: you@example.com" → double-click
it → the **Organizational Unit** field is your Team ID.

## 3. Generate and open the Xcode project

```sh
xcodegen generate
open AIMeter.xcodeproj
```

In Xcode, for **both** targets (`AIMeterMenuBar` and
`AIMeterWidgetExtension`), confirm Signing & Capabilities shows your Team
selected (it should already be filled in from `DEVELOPMENT_TEAM` in
`project.yml`) with no red errors. No other capabilities need adding —
there's no App Group or Keychain Sharing group to configure.

Build and run (`AIMeterMenuBar` scheme). To confirm signing actually took
(not just that Xcode shows no error):

```sh
codesign -dvv "/path/to/AI Meter.app" 2>&1 | grep TeamIdentifier
codesign -dvv "/path/to/AI Meter.app/Contents/PlugIns/AIMeterWidgetExtension.appex" 2>&1 | grep TeamIdentifier
```

Both should print your real Team ID (not "not set") — if either shows
"not set", the app/extension is only ad-hoc signed and the widget will
never register with the system.

## 4. One-time: capture the real usage endpoint

The exact undocumented claude.ai endpoint this app calls needs to be
captured from a live, logged-in browser session — see
[`Docs/ENDPOINT_NOTES.md`](Docs/ENDPOINT_NOTES.md) for how, and fill in
`Packages/AIMeterKit/Sources/AIMeterKit/Networking/AIMeterEndpoints.swift`
/ `AIMeterAPIClient.swift` to match once you have it.

## 5. Add the widget

Open Notification Center (or your desktop) → "Edit Widgets" → search "AI
Meter" → add the Small, Medium, or Large size.

## Distribution builds (notarized)

Steps 1–5 above are for local development (Debug config, free-tier
"Apple Development" signing). Release builds — the ones published on
[GitHub Releases](https://github.com/terrykhm/ai-meter-mac-widget/releases/latest) —
are signed with a paid "Developer ID Application" certificate and
notarized by Apple, so Gatekeeper accepts them with no warnings at all on
any Mac, not just the one that built them. That needs a paid Apple
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
ditto -c -k --keepParent "/tmp/AIMeter-export/AI Meter.app" /tmp/AIMeter-notarize.zip
xcrun notarytool submit /tmp/AIMeter-notarize.zip --keychain-profile "AC_PASSWORD" --wait
xcrun stapler staple "/tmp/AIMeter-export/AI Meter.app"
```

`ExportOptions.plist` needs `method: developer-id`, your `teamID`, and
`signingCertificate: "Developer ID Application"` — it's not committed to
this repo (nothing sensitive in it, just not needed by anyone building
Debug-only). A plain `xcodebuild build` (rather than `archive` +
`-exportArchive`) will *not* produce a notarizable build even in Release
config — it always includes the `get-task-allow` debug entitlement and
skips secure timestamping, both of which notarization rejects.

## Troubleshooting a from-source build

**Widget doesn't show up in "Edit Widgets" at all.** macOS silently
refuses to register an unsandboxed WidgetKit extension with `pluginkitd`
— no error anywhere, it just never appears. If you've confirmed both
targets are actually signed with your real Team ID (step 3 above) and
it's still missing, force a re-scan:

```sh
pluginkit -a "/path/to/AI Meter.app/Contents/PlugIns/AIMeterWidgetExtension.appex"
pluginkit -m -v -p com.apple.widgetkit-extension | grep -i aimeter
```

The second command should print a line for `com.terrykhm.aimeter.widget`
(or your own bundle prefix). If it still prints nothing, check
`Widget/AIMeterWidgetExtension/AIMeterWidgetExtension.entitlements`
exists and is wired up via `CODE_SIGN_ENTITLEMENTS` in `project.yml` —
the widget target must have App Sandbox enabled for registration to work
at all, even though the main app deliberately isn't sandboxed.
