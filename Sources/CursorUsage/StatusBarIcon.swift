import AppKit

enum StatusBarIcon {
    private static let menuBarSize = NSSize(width: 18, height: 18)

    static var cursor: NSImage? {
        if let bundled = loadBundledIcon() {
            return sized(bundled)
        }
        if let fromApp = loadFromCursorApp() {
            return sized(fromApp)
        }
        return nil
    }

    private static func loadBundledIcon() -> NSImage? {
        guard let url = Bundle.main.url(forResource: "Cursor", withExtension: "icns") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }

    private static func loadFromCursorApp() -> NSImage? {
        let paths = [
            "/Applications/Cursor.app/Contents/Resources/Cursor.icns",
            NSHomeDirectory() + "/Applications/Cursor.app/Contents/Resources/Cursor.icns",
        ]
        for path in paths {
            if let image = NSImage(contentsOfFile: path) {
                return image
            }
        }
        return nil
    }

    private static func sized(_ image: NSImage) -> NSImage {
        let copy = image.copy() as? NSImage ?? image
        copy.size = menuBarSize
        copy.isTemplate = false
        return copy
    }
}
