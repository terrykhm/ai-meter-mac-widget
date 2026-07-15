import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    private static let pollIntervalOptions: [(label: String, seconds: TimeInterval)] = [
        ("1 minute", 60),
        ("5 minutes", 300),
        ("15 minutes", 900),
        ("30 minutes", 1800)
    ]

    var body: some View {
        ZStack {
            UsageColors.cardBackgroundGradient
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                header

                VStack(spacing: 14) {
                    statusRow

                    Divider().opacity(0.4)

                    row(label: "Refresh every") {
                        Picker("", selection: $appState.pollInterval) {
                            ForEach(Self.pollIntervalOptions, id: \.seconds) { option in
                                Text(option.label).tag(option.seconds)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 130)
                    }
                }
                .padding(16)
                .glassPanel(cornerRadius: 16)

                Text("This app reads your claude.ai usage using an unofficial, undocumented endpoint. See the README for details. It has no menu bar icon or Dock icon — reopen it (double-click in Finder or Spotlight) any time to get back to this window.")
                    .font(.caption)
                    .foregroundStyle(UsageColors.textSecondary())
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
        }
        .frame(width: 380, height: 350)
    }

    /// Centered rather than leading-aligned so it doesn't collide with
    /// the traffic lights, which float directly over this same
    /// transparent titlebar area (see `SettingsWindowController`).
    private var header: some View {
        HStack(spacing: 7) {
            Image("AIMeterLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
            Text("AI Meter")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(UsageColors.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var statusRow: some View {
        switch appState.authStatus {
        case .signedOut:
            HStack {
                Text("Not signed in")
                    .font(.system(size: 12.5))
                    .foregroundStyle(UsageColors.textSecondary())
                Spacer()
                pillButton("Sign in", filled: true) {
                    appState.beginSignIn()
                }
            }
        case .signingIn:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Waiting for sign-in…")
                    .font(.system(size: 12.5))
                    .foregroundStyle(UsageColors.textSecondary())
                Spacer()
            }
        case .signedIn:
            HStack {
                Label("Signed in", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.green)
                Spacer()
                pillButton("Sign out", filled: false) {
                    appState.signOut()
                }
            }
        }
    }

    private func row<Trailing: View>(label: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12.5))
                .foregroundStyle(UsageColors.textPrimary)
            Spacer()
            trailing()
        }
    }

    private func pillButton(_ title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(filled ? .white : UsageColors.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Capsule().fill(filled ? UsageColors.accent : Color.white.opacity(0.6)))
                .overlay(Capsule().strokeBorder(UsageColors.textPrimary.opacity(filled ? 0 : 0.12)))
        }
        .buttonStyle(.plain)
    }
}
