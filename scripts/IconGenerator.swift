// AutoChoice App Icon — 1024x1024 PNG via CoreGraphics.
// macOS-only. Run: `swift scripts/IconGenerator.swift <output-path>`
//
// Visual: gradient background (pink → blue), centered 6-segment pie wheel,
// inner hub, top-pointing triangle pointer.

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import AppKit

let outPath = CommandLine.arguments.dropFirst().first ?? "icon.png"
let dim = 1024
let cs = CGColorSpace(name: CGColorSpace.sRGB)!

guard let ctx = CGContext(
    data: nil,
    width: dim, height: dim,
    bitsPerComponent: 8, bytesPerRow: 0,
    space: cs,
    bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
) else {
    fatalError("Failed to create CGContext")
}

// 1) Diagonal gradient background.
let bgColors: CFArray = [
    CGColor(red: 1.00, green: 0.00, blue: 0.43, alpha: 1.0),
    CGColor(red: 0.23, green: 0.52, blue: 1.00, alpha: 1.0)
] as CFArray
let bgGrad = CGGradient(colorsSpace: cs, colors: bgColors, locations: [0.0, 1.0])!
ctx.drawLinearGradient(bgGrad, start: .zero, end: CGPoint(x: dim, y: dim), options: [])

let center = CGPoint(x: dim / 2, y: dim / 2)

// 2) White rounded ring (gives the wheel a clean disc feel).
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.97))
ctx.fillEllipse(in: CGRect(x: 132, y: 132, width: 760, height: 760))

// 3) Six pie slices.
let palette: [CGColor] = [
    CGColor(red: 1.00, green: 0.39, blue: 0.27, alpha: 1), // tomato
    CGColor(red: 1.00, green: 0.72, blue: 0.20, alpha: 1), // amber
    CGColor(red: 0.30, green: 0.80, blue: 0.30, alpha: 1), // green
    CGColor(red: 0.20, green: 0.60, blue: 0.95, alpha: 1), // sky
    CGColor(red: 0.55, green: 0.40, blue: 0.93, alpha: 1), // purple
    CGColor(red: 1.00, green: 0.39, blue: 0.78, alpha: 1)  // pink
]
let segments = 6
let segRadius: CGFloat = 320

for i in 0..<segments {
    let startAngle = CGFloat(i) * (.pi * 2 / CGFloat(segments)) - .pi / 2
    let endAngle = startAngle + (.pi * 2 / CGFloat(segments))
    ctx.setFillColor(palette[i])
    ctx.beginPath()
    ctx.move(to: center)
    ctx.addArc(center: center, radius: segRadius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
    ctx.closePath()
    ctx.fillPath()
}

// 4) Slice separator lines (white).
ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
ctx.setLineWidth(6)
for i in 0..<segments {
    let angle = CGFloat(i) * (.pi * 2 / CGFloat(segments)) - .pi / 2
    let ex = center.x + segRadius * cos(angle)
    let ey = center.y + segRadius * sin(angle)
    ctx.move(to: center)
    ctx.addLine(to: CGPoint(x: ex, y: ey))
    ctx.strokePath()
}

// 5) Inner hub (white outer circle, dark center).
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
ctx.fillEllipse(in: CGRect(x: 462, y: 462, width: 100, height: 100))
ctx.setFillColor(CGColor(red: 0.05, green: 0.05, blue: 0.10, alpha: 1))
ctx.fillEllipse(in: CGRect(x: 487, y: 487, width: 50, height: 50))

// 6) Top pointer triangle (Y-axis is up: 1024 is top).
ctx.setFillColor(CGColor(red: 0.05, green: 0.05, blue: 0.10, alpha: 1))
ctx.beginPath()
ctx.move(to: CGPoint(x: 512, y: 884))
ctx.addLine(to: CGPoint(x: 462, y: 804))
ctx.addLine(to: CGPoint(x: 562, y: 804))
ctx.closePath()
ctx.fillPath()

// Save as PNG.
guard let img = ctx.makeImage() else { fatalError("makeImage failed") }
let url = URL(fileURLWithPath: outPath)
guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fatalError("CGImageDestination failed")
}
CGImageDestinationAddImage(dest, img, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("Finalize failed") }
print("wrote \(url.path)")
