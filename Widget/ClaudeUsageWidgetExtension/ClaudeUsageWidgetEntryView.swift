import SwiftUI
import WidgetKit
import ClaudeUsageKit

/// Small + Medium + Large widget faces, styled per the "Warm Frosted"
/// mockup. All sizes fall back to a real "sign in" prompt (matching the
/// popover) when there's no cached snapshot yet, rather than showing
/// dimmed fake data.
struct ClaudeUsageWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: UsageWidgetEntry

    var body: some View {
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
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(UsageColors.cardBackgroundGradient, for: .widget)
    }
}

private struct SignedOutView: View {
    var body: some View {
        VStack(spacing: 10) {
            ClaudeLogoMark(size: 40)
            Text("Sign in to see\nyour usage")
                .font(.system(size: 11.5))
                .foregroundStyle(UsageColors.textSecondary())
                .multilineTextAlignment(.center)
                .lineSpacing(1)
        }
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

private struct SmallSignedInView: View {
    var snapshot: UsageSnapshot
    var primary: WindowUsage
    var isStale: Bool

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                ClaudeLogoMark(size: 20)
                Spacer()
                if let plan = snapshot.planName {
                    PlanBadge(text: plan)
                }
            }

            UsageRing(utilization: primary.utilization, diameter: 78, trackWidth: 9)
                .overlay(
                    Text(UsageFormatting.percentString(primary))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(UsageColors.textPrimary)
                )

            if let resets = UsageFormatting.resetsInString(primary) {
                Text(isStale ? "\(resets) · stale" : resets)
                    .font(.system(size: 10.5))
                    .foregroundStyle(UsageColors.textSecondary())
            }
        }
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
/// instead.
private struct MediumSignedInView: View {
    var snapshot: UsageSnapshot
    var primary: WindowUsage
    var other: WindowUsage?
    var isStale: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            BrandRow(snapshot: snapshot, dotSize: 20, titleSize: 12)

            VStack(alignment: .leading, spacing: 10) {
                UsageProgressRow(usage: primary, tint: UsageColors.accent)
                if let other {
                    UsageProgressRow(usage: other, tint: UsageColors.accentSecondary)
                }
            }

            if isStale {
                Text("Stale — reopen Claude Usage to refresh")
                    .font(.system(size: 9.5))
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
