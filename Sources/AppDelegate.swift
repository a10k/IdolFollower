import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenu()
        WindowManager.shared.restoreOrCreate()
    }

    func applicationWillTerminate(_ notification: Notification) {
        WindowManager.shared.saveAll()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false  // WindowManager calls NSApp.terminate when the last window closes
    }

    // MARK: - Actions

    @objc func newWindow() {
        WindowManager.shared.openNewWindow()
    }

    @objc func changeModel() {
        guard let window = NSApp.keyWindow else { return }
        WindowManager.shared.changeModel(for: window)
    }

    // MARK: - Menu

    private func setupMenu() {
        let menu = NSMenu()

        let appItem = NSMenuItem()
        menu.addItem(appItem)
        let appMenu = NSMenu()
        appItem.submenu = appMenu
        appMenu.addItem(NSMenuItem(title: "Quit Idol Follower",
                                   action: #selector(NSApplication.terminate(_:)),
                                   keyEquivalent: "q"))

        let fileItem = NSMenuItem()
        menu.addItem(fileItem)
        let fileMenu = NSMenu(title: "File")
        fileItem.submenu = fileMenu
        fileMenu.addItem(NSMenuItem(title: "New Window",
                                    action: #selector(newWindow),
                                    keyEquivalent: "n"))
        fileMenu.addItem(.separator())
        fileMenu.addItem(NSMenuItem(title: "Change Model…",
                                    action: #selector(changeModel),
                                    keyEquivalent: "o"))
        fileMenu.addItem(.separator())
        fileMenu.addItem(NSMenuItem(title: "Close",
                                    action: #selector(NSWindow.performClose(_:)),
                                    keyEquivalent: "w"))

        NSApp.mainMenu = menu
    }
}
