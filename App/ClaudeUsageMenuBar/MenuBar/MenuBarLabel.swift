import SwiftUI

/// Compact status-item content: a gradient mark plus a text label. Always
/// renders a non-empty label — a dot alone (previously 8pt with no text)
/// is easy to miss entirely in a real menu bar, which read as "the app
/// isn't running" even when it was.
struct MenuBarLabel: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(UsageColors.accentGradient)
                .frame(width: 10, height: 10)

            if let usage = appState.snapshot?.bindingWindow {
                Text("\(usage.percentInt)%")
                    .font(.system(size: 12, weight: .semibold))
            } else {
                Text("Claude")
                    .font(.system(size: 12, weight: .semibold))
            }
        }
    }
}
