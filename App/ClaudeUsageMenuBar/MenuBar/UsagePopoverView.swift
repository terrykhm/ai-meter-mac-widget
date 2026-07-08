import SwiftUI
import ClaudeUsageKit

/// The menu bar dropdown. Styled per the "Warm Frosted" mockup: a frosted
/// glass card, a circular usage ring for the primary (5-hour) window, and
/// a secondary row for the next window (7-day), with real sign-in/sign-out
/// states rather than the mockup's dimmed-ghost-data preview trick.
struct UsagePopoverView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            switch appState.authStatus {
            case .signedOut:
                signedOutContent
            case .signingIn:
                signingInContent
            case .signedIn:
                signedInContent
            }
        }
        .padding(18)
        .frame(width: 300)
        .glassPanel(cornerRadius: 20)
        .task {
            if appState.authStatus == .signedIn {
                await appState.refresh()
            }
        }
    }

    private var signedOutContent: some View {
        VStack(spacing: 12) {
            Circle()
                .fill(UsageColors.accentGradient)
                .frame(width: 40, height: 40)
                .overlay(
                    Text("C")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                )

            Text("Sign in to see your usage")
                .font(.system(size: 12))
                .foregroundStyle(UsageColors.textSecondary())
                .multilineTextAlignment(.center)

            Button {
                appState.beginSignIn()
            } label: {
                Text("Sign in")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(UsageColors.accent))
                    .shadow(color: UsageColors.signInButtonShadow, radius: 8, y: 4)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }

    private var signingInContent: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text("Waiting for sign-in…")
                .font(.caption)
                .foregroundStyle(UsageColors.textSecondary())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var signedInContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if let snapshot = appState.snapshot, let primary = snapshot.fiveHourWindow ?? snapshot.bindingWindow {
                HStack(spacing: 16) {
                    UsageRing(utilization: primary.utilization, diameter: 56, trackWidth: 8)
                        .overlay(
                            Text(UsageFormatting.percentString(primary))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(UsageColors.textPrimary)
                        )
                    VStack(alignment: .leading, spacing: 4) {
                        if let used = UsageFormatting.usedOfLimitString(primary) {
                            Text(used)
                                .font(.system(size: 12))
                                .foregroundStyle(UsageColors.textSecondary(0.7))
                        }
                        if let resets = UsageFormatting.resetsInString(primary) {
                            Text(resets)
                                .font(.system(size: 12))
                                .foregroundStyle(UsageColors.textSecondary())
                        }
                    }
                }

                if let other = snapshot.windows.first(where: { $0.id != primary.id }) {
                    Divider()
                    WindowUsageRow(usage: other)
                }

                if appState.lastError != .none, let message = appState.lastError.userMessage {
                    Text(message)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.orange)
                }

                Text(UsageFormatting.lastUpdatedString(snapshot))
                    .font(.system(size: 10))
                    .foregroundStyle(UsageColors.textSecondary(0.4))
            } else if appState.lastError != .none, let message = appState.lastError.userMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }

            HStack {
                Button("Refresh") {
                    Task { await appState.refresh() }
                }
                .buttonStyle(.plain)
                .font(.system(size: 10.5))
                .foregroundStyle(UsageColors.textSecondary(0.5))

                Spacer()

                Button("Sign out") {
                    appState.signOut()
                }
                .buttonStyle(.plain)
                .font(.system(size: 10.5))
                .foregroundStyle(UsageColors.textSecondary(0.4))
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(UsageColors.accentGradient)
                .frame(width: 26, height: 26)
                .overlay(
                    Text("C")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                )
            Text("Claude")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(UsageColors.textPrimary)
            Spacer()
            if let plan = appState.snapshot?.planName {
                PlanBadge(text: plan)
            }
        }
    }
}
