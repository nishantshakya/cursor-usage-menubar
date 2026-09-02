#!/usr/bin/env swift
import AppKit
import SwiftUI

// MARK: - Menu bar chart (matches StatusBarChart.swift)

enum MenuBarChartRenderer {
    private static let iconSize: CGFloat = 18
    private static let barWidth: CGFloat = 40
    private static let barHeight: CGFloat = 7
    private static let gap: CGFloat = 5

    static func makeImage(percent: Double?, isError: Bool, cursorIcon: NSImage?) -> NSImage {
        let totalWidth = iconSize + gap + barWidth
        let totalHeight = iconSize

        return NSImage(size: NSSize(width: totalWidth, height: totalHeight), flipped: false) { _ in
            if let cursorIcon {
                let iconRect = NSRect(x: 0, y: (totalHeight - iconSize) / 2, width: iconSize, height: iconSize)
                cursorIcon.draw(in: iconRect)
            }

            let barX = iconSize + gap
            let barY = (totalHeight - barHeight) / 2
            let barRect = NSRect(x: barX, y: barY, width: barWidth, height: barHeight)
            let cornerRadius = barHeight / 2

            NSColor.labelColor.withAlphaComponent(0.18).setFill()
            NSBezierPath(roundedRect: barRect, xRadius: cornerRadius, yRadius: cornerRadius).fill()

            if isError {
                NSColor.systemRed.setFill()
                let fillRect = NSRect(x: barX, y: barY, width: barWidth * 0.15, height: barHeight)
                NSBezierPath(roundedRect: fillRect, xRadius: cornerRadius, yRadius: cornerRadius).fill()
            } else if let percent {
                let fraction = min(max(percent / 100.0, 0), 1.0)
                if fraction > 0 {
                    let fillWidth = max(barWidth * fraction, barHeight)
                    let fillRect = NSRect(x: barX, y: barY, width: fillWidth, height: barHeight)
                    fillColor(for: percent).setFill()
                    NSBezierPath(roundedRect: fillRect, xRadius: cornerRadius, yRadius: cornerRadius).fill()
                }
            }

            return true
        }
    }

    private static func fillColor(for percent: Double) -> NSColor {
        if percent >= 100 { return .systemRed }
        if percent >= 80 { return .systemOrange }
        return .systemBlue
    }
}

// MARK: - Popover preview (sample data for README)

private struct PopoverPreview: View {
    let spendCents: Int
    let quotaCents: Int
    let percent: Double
    let plan: String
    let billing: String
    let workingDays: Int
    let monthlyUsed: Int
    let monthlyLimit: Int
    let monthlyRemaining: Int
    let categories: [(String, Int)]

    private var progress: Double { min(percent / 100.0, 1.0) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Cursor Usage")
                    .font(.headline)
                Spacer()
                Image(systemName: "arrow.clockwise")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Today")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(formatDollars(spendCents))
                            .font(.title2.weight(.semibold))
                        Text("/ \(formatDollars(quotaCents))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.0f%%", percent))
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(progressColor)
                    }

                    ProgressView(value: progress)
                        .tint(progressColor)

                    Text("Daily quota = monthly limit ÷ working days")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(10)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                labelRow("Plan", plan)
                labelRow("Billing", billing)
                labelRow("Working days", "\(workingDays)")

                if !categories.isEmpty {
                    Divider()
                    Text("By category")
                        .font(.subheadline.weight(.semibold))
                        .padding(.top, 4)
                    ForEach(categories.indices, id: \.self) { index in
                        labelRow(categories[index].0, formatDollars(categories[index].1))
                    }
                }

                Divider()
                Text("Monthly included")
                    .font(.subheadline.weight(.semibold))
                    .padding(.top, 4)
                ProgressView(value: Double(monthlyUsed) / Double(monthlyLimit))
                    .tint(Double(monthlyUsed) / Double(monthlyLimit) > 0.8 ? .orange : .blue)
                labelRow("Used / limit", "\(formatDollars(monthlyUsed)) / \(formatDollars(monthlyLimit))")
                labelRow("Remaining", formatDollars(monthlyRemaining))
            }
        }
        .padding(14)
        .frame(width: 300)
    }

    private var progressColor: Color {
        if progress >= 1.0 { return .red }
        if progress >= 0.8 { return .orange }
        return .blue
    }

    private func labelRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.caption)
    }

    private func formatDollars(_ cents: Int) -> String {
        let dollars = Double(cents) / 100.0
        if abs(dollars - floor(dollars)) < 0.005 {
            return String(format: "$%.0f", dollars)
        }
        return String(format: "$%.2f", dollars)
    }
}

// MARK: - Image export

func loadCursorIcon() -> NSImage? {
    let paths = [
        "/Applications/Cursor.app/Contents/Resources/Cursor.icns",
        NSHomeDirectory() + "/Applications/Cursor.app/Contents/Resources/Cursor.icns",
    ]
    for path in paths {
        if let image = NSImage(contentsOfFile: path) {
            let copy = image.copy() as? NSImage ?? image
            copy.size = NSSize(width: 18, height: 18)
            return copy
        }
    }
    return nil
}

func savePNG(_ image: NSImage, to url: URL, scale: CGFloat = 2) {
    let size = image.size
    let pixelWidth = Int(size.width * scale)
    let pixelHeight = Int(size.height * scale)

    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelWidth,
        pixelsHigh: pixelHeight,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { return }

    rep.size = size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(
        in: NSRect(x: 0, y: 0, width: size.width, height: size.height),
        from: .zero,
        operation: .copy,
        fraction: 1.0
    )
    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else { return }
    try? data.write(to: url)
}

func menuBarScreenshot(
    percent: Double?,
    isError: Bool,
    darkMode: Bool,
    cursorIcon: NSImage?
) -> NSImage {
    let chart = MenuBarChartRenderer.makeImage(percent: percent, isError: isError, cursorIcon: cursorIcon)
    let padding = NSEdgeInsets(top: 10, left: 14, bottom: 10, right: 14)
    let width = chart.size.width + padding.left + padding.right
    let height = chart.size.height + padding.top + padding.bottom

    return NSImage(size: NSSize(width: width, height: height), flipped: false) { _ in
        (darkMode ? NSColor(white: 0.18, alpha: 1) : NSColor(white: 0.94, alpha: 1)).setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: width, height: height)).fill()

        let chartRect = NSRect(
            x: padding.left,
            y: padding.bottom,
            width: chart.size.width,
            height: chart.size.height
        )
        chart.draw(in: chartRect)
        return true
    }
}

@MainActor
func renderPopover(_ view: some View, size: CGSize) -> NSImage? {
    let renderer = ImageRenderer(content: view)
    renderer.scale = 2
    return renderer.nsImage
}

// MARK: - Main

let root = URL(fileURLWithPath: CommandLine.arguments[0])
    .deletingLastPathComponent()
    .deletingLastPathComponent()
let outputDir = root.appendingPathComponent("docs/screenshots")
try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

let cursorIcon = loadCursorIcon()

let menuBarStates: [(String, Double?, Bool)] = [
    ("menubar-loading", nil, false),
    ("menubar-low", 25, false),
    ("menubar-warning", 85, false),
    ("menubar-over-quota", 110, false),
    ("menubar-error", nil, true),
]

for (name, percent, isError) in menuBarStates {
    for (suffix, dark) in [("light", false), ("dark", true)] {
        let image = menuBarScreenshot(percent: percent, isError: isError, darkMode: dark, cursorIcon: cursorIcon)
        savePNG(image, to: outputDir.appendingPathComponent("\(name)-\(suffix).png"))
    }
}

Task { @MainActor in
    let popover = PopoverPreview(
        spendCents: 1847,
        quotaCents: 2500,
        percent: 74,
        plan: "Pro",
        billing: "Sep 1, 2026 – Oct 1, 2026",
        workingDays: 21,
        monthlyUsed: 12850,
        monthlyLimit: 52500,
        monthlyRemaining: 39650,
        categories: [("Default", 1520), ("Composer", 327)]
    )
    .padding()
    .background(Color(nsColor: .windowBackgroundColor))

    if let image = renderPopover(popover, size: CGSize(width: 328, height: 420)) {
        savePNG(image, to: outputDir.appendingPathComponent("popover-details.png"))
    }

    print("Screenshots written to \(outputDir.path)")
    exit(0)
}

RunLoop.main.run()
