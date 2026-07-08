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
        Form {
            Picker("Refresh every", selection: $appState.pollInterval) {
                ForEach(Self.pollIntervalOptions, id: \.seconds) { option in
                    Text(option.label).tag(option.seconds)
                }
            }

            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    LaunchAtLoginManager.setEnabled(newValue)
                }

            if appState.authStatus == .signedIn {
                Button("Sign out") {
                    appState.signOut()
                }
            }

            Text("This app reads your claude.ai usage using an unofficial, undocumented endpoint. See the README for details.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 340)
    }
}
