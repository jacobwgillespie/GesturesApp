#!/usr/bin/env swift
import AppKit
import CoreGraphics

// ---------------------------------------------------------------------------
// Gestures app icon generator
//
// Design: three circles arranged as fingertips in a natural touch position
// on a rich teal background. One metaphor, maximum restraint.
//
// Run from the project root:
//   swift scripts/generate-icon.swift
// ---------------------------------------------------------------------------

let assetDir = "Sources/GesturesApp/Resources/Assets.xcassets/AppIcon.appiconset"

func generateIcon(pixelSize: Int, outputName: String) {
    let s = CGFloat(pixelSize)
    let scale = s / 1024.0

    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let ctx = CGContext(
        data: nil,
        width: pixelSize,
        height: pixelSize,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        fatalError("Failed to create graphics context")
    }

    // Flip to top-left origin, then scale to design coordinates (1024x1024)
    ctx.translateBy(x: 0, y: s)
    ctx.scaleBy(x: 1, y: -1)
    ctx.scaleBy(x: scale, y: scale)

    let squirclePath = CGPath(
        roundedRect: CGRect(x: 0, y: 0, width: 1024, height: 1024),
        cornerWidth: 228,
        cornerHeight: 228,
        transform: nil
    )

    // ── Background ────────────────────────────────────────────────────────

    ctx.saveGState()
    ctx.addPath(squirclePath)
    ctx.clip()

    // Solid teal with a very subtle radial luminosity shift (brighter center)
    // Base fill
    ctx.setFillColor(CGColor(srgbRed: 0.051, green: 0.580, blue: 0.533, alpha: 1))  // #0d9488
    ctx.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))

    // Subtle radial highlight at center
    let radialColors: [CGColor] = [
        CGColor(srgbRed: 0.082, green: 0.702, blue: 0.651, alpha: 0.35),  // lighter teal, partial
        CGColor(srgbRed: 0.082, green: 0.702, blue: 0.651, alpha: 0),     // fades out
    ]
    let radialGrad = CGGradient(
        colorsSpace: colorSpace,
        colors: radialColors as CFArray,
        locations: [0, 1]
    )!
    ctx.drawRadialGradient(
        radialGrad,
        startCenter: CGPoint(x: 512, y: 480),
        startRadius: 0,
        endCenter: CGPoint(x: 512, y: 480),
        endRadius: 420,
        options: []
    )

    // Subtle top highlight
    let hlColors: [CGColor] = [
        CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.08),
        CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0),
    ]
    let hlGrad = CGGradient(colorsSpace: colorSpace, colors: hlColors as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(hlGrad, start: CGPoint.zero, end: CGPoint(x: 0, y: 420), options: [])

    // Subtle bottom shade
    let shColors: [CGColor] = [
        CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0),
        CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.10),
    ]
    let shGrad = CGGradient(colorsSpace: colorSpace, colors: shColors as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(shGrad, start: CGPoint(x: 0, y: 780), end: CGPoint(x: 0, y: 1024), options: [])

    // ── Three dots (fingertip touch points) ───────────────────────────────

    // Arranged as a natural three-finger touch: middle finger forward (top),
    // index and ring fingers slightly behind (bottom left/right).

    let dotRadius: CGFloat = 54
    let dots: [(x: CGFloat, y: CGFloat)] = [
        (512, 390),  // top center (middle finger)
        (378, 570),  // bottom left (index finger)
        (646, 570),  // bottom right (ring finger)
    ]

    // Very subtle shadow (just enough to lift them off the background)
    ctx.setShadow(
        offset: CGSize(width: 0, height: 4),
        blur: 8,
        color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.15)
    )

    ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))

    for dot in dots {
        ctx.fillEllipse(in: CGRect(
            x: dot.x - dotRadius,
            y: dot.y - dotRadius,
            width: dotRadius * 2,
            height: dotRadius * 2
        ))
    }

    ctx.restoreGState()

    // ── Outer border ──────────────────────────────────────────────────────

    ctx.setStrokeColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.08))
    ctx.setLineWidth(1.0)
    ctx.addPath(CGPath(
        roundedRect: CGRect(x: 0.5, y: 0.5, width: 1023, height: 1023),
        cornerWidth: 227.5,
        cornerHeight: 227.5,
        transform: nil
    ))
    ctx.strokePath()

    // ── Export ─────────────────────────────────────────────────────────────

    guard let cgImage = ctx.makeImage() else {
        fatalError("Failed to create CGImage")
    }

    let rep = NSBitmapImageRep(cgImage: cgImage)
    rep.size = NSSize(width: pixelSize, height: pixelSize)

    guard let pngData = rep.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) else {
        fatalError("Failed to create PNG data")
    }

    let outputPath = "\(assetDir)/\(outputName)"
    (pngData as NSData).write(toFile: outputPath, atomically: true)
    print("  \(outputPath) (\(pixelSize)×\(pixelSize))")
}

// ---------------------------------------------------------------------------

print("Generating app icons…")
generateIcon(pixelSize: 1024, outputName: "AppIcon-1024.png")
generateIcon(pixelSize: 512,  outputName: "AppIcon-512.png")
print("Done.")
