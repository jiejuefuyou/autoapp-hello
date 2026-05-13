import SwiftUI

/// Press feedback for custom-styled buttons (filled background + foreground
/// drawn manually inside the label). SwiftUI's default `.borderless` /
/// `.plain` styles don't animate these, so the button feels dead on tap.
/// Apply this on the prime CTAs (paywall purchase, onboarding next).
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
