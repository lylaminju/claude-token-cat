import AppKit

// MARK: - App Entry Point
// macOS menu bar app using NSApplicationDelegate (no SwiftUI App lifecycle)
// LSUIElement=true in Info.plist hides the dock icon

@main
struct ClaudeTokenCatApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
