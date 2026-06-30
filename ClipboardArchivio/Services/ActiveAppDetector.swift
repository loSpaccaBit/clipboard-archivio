import AppKit

enum ActiveAppDetector {
    static func current() -> (name: String?, bundleId: String?) {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return (nil, nil)
        }
        return (app.localizedName, app.bundleIdentifier)
    }
}