import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    let tracker = MouseTracker()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenu()

        let root = RootView().environmentObject(tracker)

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.isMovableByWindowBackground = true
        window.contentView = NSHostingView(rootView: root)
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.setFrameAutosaveName("IdolFollowerWindow")

        tracker.window = window
        tracker.startTracking()
    }

    @objc func changeModel() {
        let panel = NSOpenPanel()
        // No UTType filter — most 3D formats aren't registered with macOS.
        // Unsupported formats fall back to the placeholder sphere gracefully.
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.prompt = "Open"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        UserDefaults.standard.set(url.path, forKey: "modelPath")
        NotificationCenter.default.post(name: .modelURLChanged, object: url)
    }

    private func setupMenu() {
        let menu = NSMenu()

        let appItem = NSMenuItem()
        menu.addItem(appItem)
        let appSub = NSMenu()
        appItem.submenu = appSub
        appSub.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        let fileItem = NSMenuItem()
        menu.addItem(fileItem)
        let fileSub = NSMenu(title: "File")
        fileItem.submenu = fileSub
        fileSub.addItem(NSMenuItem(title: "Change Model…", action: #selector(changeModel), keyEquivalent: "o"))

        NSApp.mainMenu = menu
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

extension Notification.Name {
    static let modelURLChanged = Notification.Name("modelURLChanged")
}
