import SwiftUI
import ClaudeUsageKit

/// One row in the popover: a window's label + reset countdown on the left,
/// its percentage on the right.
struct WindowUsageRow: View {
    var usage: WindowUsage

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(usage.kind.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(UsageColors.textPrimary)
                if let resets = UsageFormatting.resetsInString(usage) {
                    Text(resets)
                        .font(.system(size: 11))
                        .foregroundStyle(UsageColors.textSecondary())
                }
            }
            Spacer()
            Text(UsageFormatting.percentString(usage))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(UsageColors.textPrimary)
        }
    }
}
