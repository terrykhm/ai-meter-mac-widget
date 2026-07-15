import SwiftUI
import WidgetKit
import AIMeterKit

/// Small + Medium + Large widget faces, styled per the "Warm Frosted"
/// mockup. All sizes fall back to a real "sign in" prompt (matching the
/// popover) when there's no cached snapshot yet, rather than showing
/// dimmed fake data.
///
/// Every size is topped with the "AI Meter" app header — this widget
/// currently only ever shows Claude data, but the app is meant to grow
/// other providers (Gemini, ChatGPT, ...) over time, so the app-level
/// brand sits above the provider-specific content rather than replacing
/// it.
struct AIMeterWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: UsageWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: headerSpacing) {
            AppBrandHeader(compact: family == .systemSmall)

            Group {
                if let snapshot = entry.snapshot, let primary = snapshot.fiveHourWindow ?? snapshot.bindingWindow {
                    let other = snapshot.windows.first { $0.id != primary.id }
                    switch family {
                    case .systemSmall:
                        SmallSignedInView(snapshot: snapshot, primary: primary, isStale: entry.errorState != .none)
                    case .systemLarge:
                        LargeSignedInView(snapshot: snapshot, primary: primary, other: other, isStale: entry.errorState != .none)
                    default:
                        MediumSignedInView(snapshot: snapshot, primary: primary, other: other, isStale: entry.errorState != .none)
                    }
                } else {
                    SignedOutView()
                }
            }
            .frame(maxHeight: .infinity)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(UsageColors.cardBackgroundGradient, for: .widget)
    }

    /// Small and Medium are both fixed at ~155pt tall on macOS (only Large
    /// gets real extra height), so a much bigger header leaves them very
    /// little room — keep the gap to the content below tight there.
    private var headerSpacing: CGFloat {
        switch family {
        case .systemSmall: return 4
        case .systemLarge: return 14
        default: return 6
        }
    }
}

/// The app-level "AI Meter" wordmark — 4x its original size. `compact`
/// still scales down for `.systemSmall`, which (like `.systemMedium`) is
/// fixed at ~155pt tall on macOS, so even the compact header now eats
/// well over a third of the widget's usable height. The per-size content
/// below has been compressed hard to still fit everything without
/// dropping any element.
private struct AppBrandHeader: View {
    var compact: Bool = false

    var body: some View {
        HStack(spacing: compact ? 5 : 6) {
            AppLogoMark(size: compact ? 20 : 24)
            Text("AI Meter")
                .font(.system(size: compact ? 14 : 17, weight: .semibold))
                .foregroundStyle(UsageColors.textPrimary)
        }
    }
}

private struct AppLogoMark: View {
    var size: CGFloat

    var body: some View {
        Image("AIMeterLogo")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// Widgets can't host the real sign-in flow (it's a full `WKWebView`
/// login window, only the app can show that) — tapping this opens the
/// app instead, via a custom URL scheme `AppDelegate` handles the same
/// way it handles being reopened: bring Settings to the front, where the
/// actual "Sign in" button lives.
private struct SignedOutView: View {
    var body: some View {
        Link(destination: URL(string: "aimeter://open")!) {
            VStack(spacing: 10) {
                ClaudeLogoMark(size: 40)
                Text("Sign in to see\nyour usage")
                    .font(.system(size: 11.5))
                    .foregroundStyle(UsageColors.textSecondary())
                    .multilineTextAlignment(.center)
                    .lineSpacing(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
    }
}

private struct BrandRow: View {
    var snapshot: UsageSnapshot
    var dotSize: CGFloat
    var titleSize: CGFloat
    var showTitle: Bool = true

    var body: some View {
        HStack(spacing: 8) {
            ClaudeLogoMark(size: dotSize)
            if showTitle {
                Text("Claude")
                    .font(.system(size: titleSize, weight: .semibold))
                    .foregroundStyle(UsageColors.textPrimary)
            }
            Spacer()
            if let plan = snapshot.planName {
                PlanBadge(text: plan)
            }
        }
    }
}

/// Compressed hard (ring 78->30, tiny type) to still fit every element
/// below the now much bigger "AI Meter" header within `.systemSmall`'s
/// fixed ~155pt square — the header alone now takes up roughly 45% of
/// the usable height.
private struct SmallSignedInView: View {
    var snapshot: UsageSnapshot
    var primary: WindowUsage
    var isStale: Bool

    var body: some View {
        VStack(spacing: 5) {
            HStack {
                ClaudeLogoMark(size: 18)
                Spacer()
                if let plan = snapshot.planName {
                    PlanBadge(text: plan)
                }
            }

            UsageRing(utilization: primary.utilization, diameter: 55, trackWidth: 6)
                .overlay(
                    Text(UsageFormatting.percentString(primary))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(UsageColors.textPrimary)
                )

            if let resets = UsageFormatting.resetsInString(primary) {
                Text(isStale ? "\(resets) · stale" : resets)
                    .font(.system(size: 10))
                    .foregroundStyle(UsageColors.textSecondary())
            }
        }
        .frame(maxHeight: .infinity)
    }
}

private struct ClaudeLogoMark: View {
    var size: CGFloat

    var body: some View {
        Image("ClaudeLogo")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// Two stacked fill bars (session + weekly) rather than a ring — the
/// mockup's version of this size uses used/limit message counts we don't
/// have from the real API, so both bars fill from `WindowUsage.utilization`
/// instead. A divider under the "AI Meter" header sets the Claude section
/// apart, per the refined mockup. Like `.systemSmall`, `.systemMedium` is
/// fixed at ~155pt tall on macOS, so this stays snug (moderate brand row,
/// tight-but-even spacing) to fit under the header + divider.
private struct MediumSignedInView: View {
    var snapshot: UsageSnapshot
    var primary: WindowUsage
    var other: WindowUsage?
    var isStale: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()

            BrandRow(snapshot: snapshot, dotSize: 20, titleSize: 12)

            VStack(alignment: .leading, spacing: 6) {
                UsageProgressRow(usage: primary, tint: UsageColors.accent)
                if let other {
                    UsageProgressRow(usage: other, tint: UsageColors.accentSecondary)
                }
            }

            if isStale {
                Text("Stale — reopen AI Meter to refresh")
                    .font(.system(size: 9))
                    .foregroundStyle(UsageColors.textSecondary(0.5))
            }
        }
    }
}

private struct LargeSignedInView: View {
    var snapshot: UsageSnapshot
    var primary: WindowUsage
    var other: WindowUsage?
    var isStale: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            BrandRow(snapshot: snapshot, dotSize: 26, titleSize: 13)

            HStack(spacing: 22) {
                UsageRing(utilization: primary.utilization, diameter: 100, trackWidth: 11)
                    .overlay(
                        VStack(spacing: 2) {
                            Text(UsageFormatting.percentString(primary))
                                .font(.system(size: 21, weight: .bold))
                                .foregroundStyle(UsageColors.textPrimary)
                            Text("used")
                                .font(.system(size: 10.5))
                                .foregroundStyle(UsageColors.textSecondary())
                        }
                    )

                VStack(alignment: .leading, spacing: 12) {
                    if let other {
                        LargeStat(label: other.kind.displayName.uppercased(), value: UsageFormatting.percentString(other))
                    }
                    if let resets = UsageFormatting.resetsInString(primary) {
                        LargeStat(label: "RESETS IN", value: isStale ? "\(resets) · stale" : resets)
                    }
                }
                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)

            Divider()
            Text(UsageFormatting.lastUpdatedString(snapshot))
                .font(.system(size: 10.5))
                .foregroundStyle(UsageColors.textSecondary(0.5))
        }
    }
}

private struct LargeStat: View {
    var label: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(UsageColors.textSecondary())
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(UsageColors.textPrimary)
        }
    }
}
