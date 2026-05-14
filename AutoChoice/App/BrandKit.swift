import SwiftUI

// MARK: - Brand colors (AutoChoice — wheel randomizer)
// brandPrimary:   #F72585  vibrant pink (matches wheel icon gradient start)
// brandSecondary: #3366F2  blue (gradient end)
// brandTint:      #7C3AED  purple midpoint

extension Color {

    // Per-app brand
    static let brandPrimary   = Color(red: 0.97, green: 0.14, blue: 0.52)
    static let brandSecondary = Color(red: 0.20, green: 0.40, blue: 0.95)
    static let brandTint      = Color(red: 0.49, green: 0.23, blue: 0.93)

    // Shared semantic surfaces (same across all 4 apps)
    static let surface          = Color(uiColor: .secondarySystemBackground)
    static let surfaceElevated  = Color(uiColor: .tertiarySystemBackground)
    static let onSurface        = Color.primary
    static let onSurfaceSecondary = Color.secondary

    // Shared semantic status (same across all 4 apps)
    static let success = Color(red: 0.20, green: 0.65, blue: 0.45)   // emerald
    static let warning = Color(red: 0.95, green: 0.60, blue: 0.20)   // amber
    static let error   = Color(red: 0.85, green: 0.25, blue: 0.30)   // red

    // Urgency scale — for countdown / progress semantics
    static let urgent   = Color.error
    static let upcoming = Color.warning
    static let stable   = Color.primary
}

// MARK: - Typography (shared across 4 apps)

enum Typography {
    static let h1           = Font.system(.largeTitle, design: .rounded, weight: .heavy)
    static let h2           = Font.system(.title,      design: .rounded, weight: .bold)
    static let h3           = Font.system(.title3,     design: .default, weight: .semibold)
    static let body         = Font.system(.body,       design: .default)
    static let bodyEmphasis = Font.system(.body,       design: .default, weight: .semibold)
    static let caption      = Font.system(.caption,    design: .default)
    static let captionEmphasis = Font.system(.caption, design: .default, weight: .medium)
    static let monospace    = Font.system(.body,       design: .monospaced)

    /// Display number — for countdown / score / large data readouts
    static let displayNumber = Font.system(size: 56, weight: .heavy, design: .rounded)

    /// Tabular figures — for time / altitude reads (consistent digit width)
    static var tabularBody: Font {
        Font.system(.body, design: .monospaced).monospacedDigit()
    }
}

// MARK: - Spacing (shared)

enum Spacing {
    static let xs:  CGFloat = 4
    static let sm:  CGFloat = 8
    static let md:  CGFloat = 16
    static let lg:  CGFloat = 24
    static let xl:  CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - Corner radius (shared)

enum Radius {
    static let sm:   CGFloat = 6
    static let md:   CGFloat = 12
    static let lg:   CGFloat = 20
    static let pill: CGFloat = 999
}

// MARK: - Elevation / shadow (shared)

struct ShadowSpec {
    let color:  Color
    let radius: CGFloat
    let x:      CGFloat
    let y:      CGFloat
}

enum Elevation {
    static let card  = ShadowSpec(color: .black.opacity(0.06), radius: 6,  x: 0, y: 2)
    static let hover = ShadowSpec(color: .black.opacity(0.12), radius: 16, x: 0, y: 6)
}

extension View {
    func brandCardShadow(_ spec: ShadowSpec = Elevation.card) -> some View {
        self.shadow(color: spec.color, radius: spec.radius, x: spec.x, y: spec.y)
    }
}
