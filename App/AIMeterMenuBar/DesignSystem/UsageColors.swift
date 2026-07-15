import SwiftUI

/// Color/shape tokens for the "Warm Frosted" visual direction (cream +
/// terracotta glass, circular progress ring, pill badges/buttons), taken
/// directly from the approved Claude Design mockup. Shared by the menu bar
/// popover and both widget faces so all three surfaces read as one system.
enum UsageColors {
    /// Primary text color.
    static let textPrimary = Color(red: 0x2B / 255, green: 0x24 / 255, blue: 0x20 / 255)

    static func textSecondary(_ opacity: Double = 0.6) -> Color {
        textPrimary.opacity(opacity)
    }

    /// Solid accent used for the progress ring fill and primary buttons.
    static let accent = Color(red: 0xDA / 255, green: 0x77 / 255, blue: 0x56 / 255)

    /// Gradient accent used for avatar/logo marks.
    static let accentGradient = LinearGradient(
        colors: [
            Color(red: 0xE0 / 255, green: 0x8B / 255, blue: 0x68 / 255),
            Color(red: 0xC2 / 255, green: 0x65 / 255, blue: 0x3F / 255)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Lighter accent shade for a second/secondary progress bar sitting
    /// next to the primary `accent`-colored one (e.g. weekly vs. session).
    static let accentSecondary = Color(red: 0xE0 / 255, green: 0x8B / 255, blue: 0x68 / 255)

    static let progressTrack = textPrimary.opacity(0.08)

    static let planBadgeText = Color(red: 0xBD / 255, green: 0x5A / 255, blue: 0x3A / 255)
    static let planBadgeBackground = Color(red: 0xC2 / 255, green: 0x68 / 255, blue: 0x3D / 255).opacity(0.15)

    static let ringTrack = textPrimary.opacity(0.1)
    static let ringInnerFill = Color(red: 0xFF / 255, green: 0xFA / 255, blue: 0xF4 / 255).opacity(0.92)

    static let signInButtonShadow = Color(red: 0xC2 / 255, green: 0x68 / 255, blue: 0x3D / 255).opacity(0.35)

    static let glassPanelShadow = Color(red: 0x96 / 255, green: 0x5A / 255, blue: 0x37 / 255).opacity(0.16)

    /// The warm cream-to-terracotta card background from the mockup.
    /// Widgets use this as their `containerBackground` since a widget
    /// can't sample the desktop behind it the way the popover's material
    /// can.
    static let cardBackgroundGradient = LinearGradient(
        colors: [
            Color(red: 0xF7 / 255, green: 0xF4 / 255, blue: 0xEC / 255),
            Color(red: 0xEF / 255, green: 0xE8 / 255, blue: 0xD9 / 255),
            Color(red: 0xE6 / 255, green: 0xDA / 255, blue: 0xC2 / 255)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
