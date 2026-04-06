#!/usr/bin/env swift
import Cocoa

// Generate app icons for cc-monitor-bar
// Design: A rounded square with a gradient background featuring a monitoring dashboard aesthetic

func createIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let context = NSGraphicsContext.current!.cgContext
    let s = size

    // === Background: rounded rect with gradient ===
    let cornerRadius = s * 0.22
    let bgRect = CGRect(x: 0, y: 0, width: s, height: s)
    let bgPath = CGPath(roundedRect: bgRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

    // Gradient: dark teal to deep blue
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradientColors = [
        CGColor(red: 0.08, green: 0.18, blue: 0.30, alpha: 1.0),  // dark navy
        CGColor(red: 0.12, green: 0.28, blue: 0.42, alpha: 1.0),  // teal blue
    ] as CFArray
    let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: [0.0, 1.0])!

    context.addPath(bgPath)
    context.clip()

    context.drawLinearGradient(gradient,
        start: CGPoint(x: 0, y: s),
        end: CGPoint(x: s, y: 0),
        options: [])

    // === Outer border glow ===
    let borderPath = CGPath(roundedRect: bgRect.insetBy(dx: s * 0.02, dy: s * 0.02),
                            cornerWidth: cornerRadius - s * 0.02,
                            cornerHeight: cornerRadius - s * 0.02,
                            transform: nil)
    context.addPath(borderPath)
    context.setStrokeColor(CGColor(red: 0.3, green: 0.6, blue: 0.85, alpha: 0.6))
    context.setLineWidth(s * 0.015)
    context.strokePath()

    // === Main chart area background ===
    let chartMargin = s * 0.12
    let chartTop = s * 0.18
    let chartBottom = s * 0.72
    let chartLeft = chartMargin
    let chartRight = s - chartMargin
    let chartWidth = chartRight - chartLeft
    let chartHeight = chartBottom - chartTop

    // Chart background with subtle rounded rect
    let chartBgRect = CGRect(x: chartLeft - s * 0.04, y: chartTop - s * 0.04,
                              width: chartWidth + s * 0.08, height: chartHeight + s * 0.08)
    let chartBgPath = CGPath(roundedRect: chartBgRect,
                              cornerWidth: s * 0.06, cornerHeight: s * 0.06, transform: nil)
    context.addPath(chartBgPath)
    context.setFillColor(CGColor(red: 0.05, green: 0.10, blue: 0.18, alpha: 0.5))
    context.fillPath()

    // === Grid lines ===
    context.setStrokeColor(CGColor(red: 0.2, green: 0.35, blue: 0.5, alpha: 0.3))
    context.setLineWidth(s * 0.004)
    for i in 0..<4 {
        let y = chartTop + chartHeight * CGFloat(i) / 3.0
        context.move(to: CGPoint(x: chartLeft, y: y))
        context.addLine(to: CGPoint(x: chartRight, y: y))
    }
    context.strokePath()

    // === Bar chart (token usage bars) ===
    let barCount = 7
    let barGap = chartWidth * 0.06
    let totalGaps = CGFloat(barCount + 1) * barGap
    let barWidth = (chartWidth - totalGaps) / CGFloat(barCount)

    // Heights representing daily usage data
    let barHeights: [CGFloat] = [0.45, 0.65, 0.55, 0.80, 0.70, 0.90, 0.60]

    for (i, heightRatio) in barHeights.enumerated() {
        let barH = chartHeight * heightRatio * 0.85
        let barX = chartLeft + barGap + CGFloat(i) * (barWidth + barGap)
        let barY = chartBottom - barH

        let barRect = CGRect(x: barX, y: barY, width: barWidth, height: barH)

        // Bar gradient
        let barGradientColors: [CGColor]
        if heightRatio > 0.75 {
            // High usage: orange/amber
            barGradientColors = [
                CGColor(red: 1.0, green: 0.75, blue: 0.2, alpha: 1.0),
                CGColor(red: 0.95, green: 0.55, blue: 0.15, alpha: 1.0),
            ]
        } else {
            // Normal usage: teal/cyan
            barGradientColors = [
                CGColor(red: 0.2, green: 0.8, blue: 0.9, alpha: 1.0),
                CGColor(red: 0.1, green: 0.6, blue: 0.75, alpha: 1.0),
            ]
        }
        let barGradient = CGGradient(colorsSpace: colorSpace,
                                      colors: barGradientColors as CFArray,
                                      locations: [0.0, 1.0])!

        let barPath = CGPath(roundedRect: barRect,
                              cornerWidth: barWidth * 0.2, cornerHeight: barWidth * 0.2,
                              transform: nil)
        context.addPath(barPath)
        context.clip()
        context.drawLinearGradient(barGradient,
            start: CGPoint(x: barX, y: barY),
            end: CGPoint(x: barX, y: chartBottom),
            options: [])
        context.resetClip()
    }

    // === "C" letter in bottom-right (Claude branding) ===
    let cSize = s * 0.22
    let cCenterX = s * 0.76
    let cCenterY = s * 0.16
    let cRadius = cSize * 0.45
    let cLineWidth = cSize * 0.14

    // Circle background
    let cBgRect = CGRect(x: cCenterX - cRadius - cLineWidth/2,
                          y: cCenterY - cRadius - cLineWidth/2,
                          width: (cRadius + cLineWidth/2) * 2,
                          height: (cRadius + cLineWidth/2) * 2)
    let cBgPath = CGPath(ellipseIn: cBgRect, transform: nil)
    context.addPath(cBgPath)
    context.setFillColor(CGColor(red: 0.08, green: 0.18, blue: 0.30, alpha: 0.8))
    context.fillPath()

    // Draw "C" arc
    context.addArc(center: CGPoint(x: cCenterX, y: cCenterY),
                    radius: cRadius,
                    startAngle: .pi * 0.25,
                    endAngle: .pi * 1.75,
                    clockwise: false)
    context.setStrokeColor(CGColor(red: 1.0, green: 0.75, blue: 0.2, alpha: 1.0))
    context.setLineWidth(cLineWidth)
    context.setLineCap(.round)
    context.strokePath()

    // === Status indicator dot (top-left) ===
    let dotCenter = CGPoint(x: s * 0.22, y: s * 0.86)
    let dotRadius = s * 0.035
    // Glow
    context.addEllipse(in: CGRect(x: dotCenter.x - dotRadius * 2,
                                    y: dotCenter.y - dotRadius * 2,
                                    width: dotRadius * 4, height: dotRadius * 4))
    context.setFillColor(CGColor(red: 0.2, green: 0.9, blue: 0.5, alpha: 0.3))
    context.fillPath()
    // Dot
    context.addEllipse(in: CGRect(x: dotCenter.x - dotRadius,
                                    y: dotCenter.y - dotRadius,
                                    width: dotRadius * 2, height: dotRadius * 2))
    context.setFillColor(CGColor(red: 0.2, green: 0.9, blue: 0.5, alpha: 1.0))
    context.fillPath()

    image.unlockFocus()
    return image
}

func saveImage(_ image: NSImage, to url: URL, size: CGFloat) {
    let newImage = NSImage(size: NSSize(width: size, height: size))
    newImage.lockFocus()
    image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    newImage.unlockFocus()

    guard let tiffData = newImage.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to create PNG data for size \(size)")
        return
    }

    do {
        try pngData.write(to: url)
        print("Saved: \(url.path)")
    } catch {
        print("Error saving \(url.path): \(error)")
    }
}

// Generate all required icon sizes
let baseURL = URL(fileURLWithPath: "/Users/ido/project/mac/cc-monitor-bar/cc-monitor-bar/Assets.xcassets/AppIcon.appiconset/")

// Create master icon at large size, then scale down
let masterIcon = createIcon(size: 1024)

let icons: [(filename: String, size: CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for icon in icons {
    saveImage(masterIcon, to: baseURL.appendingPathComponent(icon.filename), size: icon.size)
}

print("\nAll icons generated successfully!")
