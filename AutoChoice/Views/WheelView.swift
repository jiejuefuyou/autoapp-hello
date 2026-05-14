import SwiftUI

struct WheelView: View {
    let choices: [Choice]
    let rotation: Double
    let palette: [Color]
    /// Set from parent to reflect current spin state for a11y value.
    var isSpinning: Bool = false
    /// Set from parent to reflect last spin result for a11y value.
    var lastResultLabel: String? = nil

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            ZStack {
                if choices.isEmpty {
                    Circle()
                        .strokeBorder(.secondary, lineWidth: 2)
                    VStack {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text(LocalizedStringKey("Add choices to spin"))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    wheel(size: size)
                        .rotationEffect(.degrees(rotation))
                    centerHub(size: size)
                    pointer(size: size)
                }
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(
            String(format: String(localized: "Wheel with %lld choices"), Int64(choices.count))
        ))
        .accessibilityValue(isSpinning
            ? Text(LocalizedStringKey("Spinning"))
            : (lastResultLabel.map { Text($0) } ?? Text(LocalizedStringKey("Ready")))
        )
    }

    @ViewBuilder
    private func wheel(size: CGFloat) -> some View {
        // Compute weighted segment angles so the visual slice matches the spin probability.
        // All weights clamped to ≥ 0.1 to avoid zero-area segments.
        let totalWeight = choices.reduce(0.0) { $0 + max(0.1, $1.weight) }
        ZStack {
            ForEach(Array(choices.enumerated()), id: \.element.id) { idx, choice in
                let precedingWeight = choices[0..<idx].reduce(0.0) { $0 + max(0.1, $1.weight) }
                let ownWeight = max(0.1, choice.weight)
                // -90 offset so index 0 starts at the top (where the pointer is).
                let start = (precedingWeight / totalWeight) * 360.0 - 90.0
                let end   = ((precedingWeight + ownWeight) / totalWeight) * 360.0 - 90.0
                let midAngle = start + (end - start) / 2

                SegmentShape(start: .degrees(start), end: .degrees(end))
                    .fill(palette[idx % palette.count])
                    .overlay(
                        SegmentShape(start: .degrees(start), end: .degrees(end))
                            .stroke(Color.white.opacity(0.6), lineWidth: 1)
                    )
                SegmentLabel(
                    text: choice.label,
                    angleDegrees: midAngle + 90, // local angle from top for label
                    radius: size * 0.34
                )
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .shadow(radius: 6)
    }

    private func centerHub(size: CGFloat) -> some View {
        Circle()
            .fill(.background)
            .frame(width: size * 0.16, height: size * 0.16)
            .overlay(Circle().strokeBorder(.secondary.opacity(0.3), lineWidth: 1))
            .shadow(radius: 2)
    }

    private func pointer(size: CGFloat) -> some View {
        Triangle()
            .fill(Color.primary)
            .frame(width: size * 0.07, height: size * 0.09)
            .offset(y: -size / 2 + size * 0.03)
            .shadow(radius: 1.5)
    }
}

private struct SegmentShape: Shape {
    let start: Angle
    let end: Angle

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        p.move(to: center)
        p.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
        p.closeSubpath()
        return p
    }
}

private struct SegmentLabel: View {
    let text: String
    let angleDegrees: Double
    let radius: CGFloat

    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.35), radius: 1)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: radius * 1.4)
            .rotationEffect(.degrees(angleDegrees))
            .offset(
                x: sin(angleDegrees * .pi / 180) * radius,
                y: -cos(angleDegrees * .pi / 180) * radius
            )
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}
