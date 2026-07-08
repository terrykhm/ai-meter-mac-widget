import SwiftUI

/// The frosted-glass card background used throughout the "Warm Frosted"
/// design: a translucent white fill over `.regularMaterial`, a subtle
/// white border, and a soft warm shadow. Corner radius varies by context
/// (20pt for the popover, 24pt for widget cards) per the mockup.
struct GlassPanel: ViewModifier {
    var cornerRadius: CGFloat = 24

    func body(content: Content) -> some View {
        content
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.35))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.6), lineWidth: 1)
            )
            .shadow(color: UsageColors.glassPanelShadow, radius: 24, x: 0, y: 12)
    }
}

extension View {
    func glassPanel(cornerRadius: CGFloat = 24) -> some View {
        modifier(GlassPanel(cornerRadius: cornerRadius))
    }
}

/// A circular usage ring: `accent`-filled arc over a faint track, with a
/// solid inner disc for the percentage label to sit on.
struct UsageRing: View {
    var utilization: Double
    var diameter: CGFloat
    var trackWidth: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(UsageColors.ringTrack, lineWidth: trackWidth)
            Circle()
                .trim(from: 0, to: max(0, min(1, utilization)))
                .stroke(UsageColors.accent, style: StrokeStyle(lineWidth: trackWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Circle()
                .fill(UsageColors.ringInnerFill)
                .padding(trackWidth * 0.7)
        }
        .frame(width: diameter, height: diameter)
    }
}

/// The "MAX"-style plan badge pill.
struct PlanBadge: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.system(size: 9.5, weight: .semibold))
            .foregroundStyle(UsageColors.planBadgeText)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(UsageColors.planBadgeBackground))
    }
}
