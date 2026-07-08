import SwiftUI
import WidgetKit
import ClaudeUsageKit

/// Small + Medium widget faces, styled per the "Warm Frosted" mockup. Both
/// sizes fall back to a real "sign in" prompt (matching the popover) when
/// there's no cached snapshot yet, rather than showing dimmed fake data.
struct ClaudeUsageWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: UsageWidgetEntry

    var body: some View {
        Group {
            if let snapshot = entry.snapshot, let primary = snapshot.fiveHourWindow ?? snapshot.bindingWindow {
                switch family {
                case .systemSmall:
                    SmallSignedInView(snapshot: snapshot, primary: primary, isStale: entry.errorState != .none)
                default:
                    MediumSignedInView(snapshot: snapshot, primary: primary, isStale: entry.errorState != .none)
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
            Circle()
                .fill(UsageColors.accentGradient)
                .frame(width: 40, height: 40)
                .overlay(
                    Text("C")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                )
            Text("Sign in to see\nyour usage")
                .font(.system(size: 11.5))
                .foregroundStyle(UsageColors.textSecondary())
                .multilineTextAlignment(.center)
                .lineSpacing(1)
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
                Circle()
                    .fill(UsageColors.accentGradient)
                    .frame(width: 20, height: 20)
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

private struct MediumSignedInView: View {
    var snapshot: UsageSnapshot
    var primary: WindowUsage
    var isStale: Bool

    var body: some View {
        HStack(spacing: 20) {
            UsageRing(utilization: primary.utilization, diameter: 90, trackWidth: 10)
                .overlay(
                    Text(UsageFormatting.percentString(primary))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(UsageColors.textPrimary)
                )

            VStack(alignment: .leading, spacing: 6) {
                if let plan = snapshot.planName {
                    PlanBadge(text: plan)
                }
                if let used = UsageFormatting.usedOfLimitString(primary) {
                    Text(used)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(UsageColors.textPrimary)
                }
                if let resets = UsageFormatting.resetsInString(primary) {
                    Text(isStale ? "\(resets) · stale" : resets)
                        .font(.system(size: 12))
                        .foregroundStyle(UsageColors.textSecondary())
                }
            }
            Spacer(minLength: 0)
        }
    }
}
