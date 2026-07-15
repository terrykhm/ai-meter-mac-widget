import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var launchAtLogin = LaunchAtLoginManager.isEnabled

    private static let pollIntervalOptions: [(label: String, seconds: TimeInterval)] = [
        ("1 minute", 60),
        ("5 minutes", 300),
        ("15 minutes", 900),
        ("30 minutes", 1800)
    ]

    var body: some View {
        // The trailing help text lives outside the Form, as plain
        // caption text below it rather than a 4th form row — this turned
        // out not to matter for the crash this window used to hit (see
        // SettingsWindowController; the actual cause was how the window
        // itself was being sized), but it's a fine layout on its own
        // merits and it's what's proven working, so it stayed.
        VStack(alignment: .leading, spacing: 12) {
            Form {
                statusSection

                Picker("Refresh every", selection: $appState.pollInterval) {
                    ForEach(Self.pollIntervalOptions, id: \.seconds) { option in
                        Text(option.label).tag(option.seconds)
                    }
                }

                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        LaunchAtLoginManager.setEnabled(newValue)
                    }
            }

            Text("This app reads your claude.ai usage using an unofficial, undocumented endpoint. See the README for details. It has no menu bar icon or Dock icon — reopen it (double-click in Finder or Spotlight) any time to get back to this window.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(width: 340)
    }

    @ViewBuilder
    private var statusSection: some View {
        switch appState.authStatus {
        case .signedOut:
            HStack {
                Text("Not signed in")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Sign in") {
                    appState.beginSignIn()
                }
            }
        case .signingIn:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Waiting for sign-in…")
                    .foregroundStyle(.secondary)
            }
        case .signedIn:
            HStack {
                Label("Signed in", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Spacer()
                Button("Sign out") {
                    appState.signOut()
                }
            }
        }
    }
}
