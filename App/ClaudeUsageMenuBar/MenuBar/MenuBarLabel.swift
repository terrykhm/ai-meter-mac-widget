import SwiftUI

/// Compact status-item content: a small dot mark plus a text label. Always
/// renders a non-empty label — a dot alone (previously 8pt with no text)
/// is easy to miss entirely in a real menu bar, which read as "the app
/// isn't running" even when it was.
///
/// Uses an SF Symbol (`Image(systemName:)`) rather than a raw SwiftUI
/// `Shape` for the dot — `MenuBarExtra` labels render `Image`-based
/// content reliably, but a plain `Circle().fill(...)` was found not to
/// render at all in testing.
struct MenuBarLabel: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "circle.fill")
                .font(.system(size: 8))
                .foregroundStyle(UsageColors.accent)

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
