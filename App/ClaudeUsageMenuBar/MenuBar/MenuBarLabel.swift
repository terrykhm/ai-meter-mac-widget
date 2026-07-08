import SwiftUI

/// Compact status-item content: a small gradient mark, plus the binding
/// window's percentage once signed in and loaded.
struct MenuBarLabel: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(UsageColors.accentGradient)
                .frame(width: 8, height: 8)

            if let usage = appState.snapshot?.bindingWindow {
                Text("\(usage.percentInt)%")
                    .font(.system(size: 12, weight: .semibold))
            }
        }
    }
}
