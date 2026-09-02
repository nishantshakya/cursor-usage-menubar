import AppKit

enum StatusBarChart {
    private static let iconSize: CGFloat = 18
    private static let barWidth: CGFloat = 40
    private static let barHeight: CGFloat = 7
    private static let gap: CGFloat = 5

    static func makeImage(percent: Double?, isError: Bool) -> NSImage? {
        let totalWidth = iconSize + gap + barWidth
        let totalHeight = iconSize

        return NSImage(size: NSSize(width: totalWidth, height: totalHeight), flipped: false) { rect in
            let icon = StatusBarIcon.cursor
            if let icon {
                let iconRect = NSRect(x: 0, y: (totalHeight - iconSize) / 2, width: iconSize, height: iconSize)
                icon.draw(in: iconRect)
            }

            let barX = iconSize + gap
            let barY = (totalHeight - barHeight) / 2
            let barRect = NSRect(x: barX, y: barY, width: barWidth, height: barHeight)
            let cornerRadius = barHeight / 2

            let trackColor = NSColor.labelColor.withAlphaComponent(0.18)
            trackColor.setFill()
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
