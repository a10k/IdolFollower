import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {

    private let appMenuDelegate = AppMenuDelegate()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenu()
        WindowManager.shared.restoreOrCreate()
    }

    func applicationWillTerminate(_ notification: Notification) {
        WindowManager.shared.saveAll()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    // MARK: - Actions

    @objc func newWindow() {
        WindowManager.shared.openNewWindow()
    }

    @objc func closeKeyWindow() {
        WindowManager.shared.closeKeyWindow()
    }

    @objc func focusWindow(_ sender: NSMenuItem) {
        (sender.representedObject as? NSWindow)?.makeKeyAndOrderFront(nil)
    }

    @objc func changeModelForWindow(_ sender: NSMenuItem) {
        guard let window = sender.representedObject as? NSWindow else { return }
        WindowManager.shared.changeModel(for: window)
    }

    @objc func closeSpecificWindow(_ sender: NSMenuItem) {
        (sender.representedObject as? NSWindow)?.close()
    }

    @objc func toggleAxisLock(_ sender: NSMenuItem) {
        guard let window = sender.representedObject as? NSWindow,
              let ctx = WindowManager.shared.allWindows().first(where: { $0.window === window })?.context
        else { return }
        switch sender.tag {
        case 0: ctx.lockTilt.toggle()
        case 1: ctx.lockSpin.toggle()
        case 2: ctx.lockRoll.toggle()
        default: break
        }
    }

    // MARK: - Menu

    private func setupMenu() {
        let menu = NSMenu()

        let appItem = NSMenuItem()
        menu.addItem(appItem)

        let appMenu = NSMenu()
        appMenu.delegate = appMenuDelegate
        appItem.submenu = appMenu

        NSApp.mainMenu = menu
    }
}

// MARK: - Single app menu delegate

private final class AppMenuDelegate: NSObject, NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        menu.addItem(NSMenuItem(title: "New Window",
                                action: #selector(AppDelegate.newWindow),
                                keyEquivalent: "n"))
        menu.addItem(NSMenuItem(title: "Close Window",
                                action: #selector(AppDelegate.closeKeyWindow),
                                keyEquivalent: "w"))

        let windows = WindowManager.shared.allWindows()
            .sorted { $0.window.frame.origin.x < $1.window.frame.origin.x }

        if !windows.isEmpty {
            menu.addItem(.separator())

            for (index, info) in windows.enumerated() {
                let modelName = info.context.modelURL?.deletingPathExtension().lastPathComponent
                    ?? "New Window"
                let x = Int(info.window.frame.origin.x)
                let y = Int(info.window.frame.origin.y)

                let keyEq = index < 9 ? "\(index + 1)" : ""
                let item = NSMenuItem(title: modelName,
                                      action: #selector(AppDelegate.focusWindow(_:)),
                                      keyEquivalent: keyEq)
                item.attributedTitle = menuTitle(name: modelName, position: "\(x)×\(y)")
                item.representedObject = info.window
                item.state = info.window.isKeyWindow ? .on : .off

                let sub = NSMenu()

                let changeItem = NSMenuItem(title: "Change Model…",
                                            action: #selector(AppDelegate.changeModelForWindow(_:)),
                                            keyEquivalent: "")
                changeItem.representedObject = info.window
                sub.addItem(changeItem)

                sub.addItem(.separator())

                let lockDefs: [(title: String, tag: Int, locked: Bool)] = [
                    ("Lock Tilt",  0, info.context.lockTilt),
                    ("Lock Spin",  1, info.context.lockSpin),
                    ("Lock Roll",  2, info.context.lockRoll),
                ]
                for def in lockDefs {
                    let lockItem = NSMenuItem(title: def.title,
                                             action: #selector(AppDelegate.toggleAxisLock(_:)),
                                             keyEquivalent: "")
                    lockItem.tag = def.tag
                    lockItem.representedObject = info.window
                    lockItem.state = def.locked ? .on : .off
                    sub.addItem(lockItem)
                }

                sub.addItem(.separator())

                let closeItem = NSMenuItem(title: "Close",
                                           action: #selector(AppDelegate.closeSpecificWindow(_:)),
                                           keyEquivalent: "")
                closeItem.representedObject = info.window
                sub.addItem(closeItem)

                item.submenu = sub

                menu.addItem(item)
            }
        }

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Idol Follower",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
    }

    private func menuTitle(name: String, position: String) -> NSAttributedString {
        let result = NSMutableAttributedString(
            string: name,
            attributes: [.font: NSFont.menuFont(ofSize: 0)]
        )
        result.append(NSAttributedString(
            string: "  \(position)",
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        ))
        return result
    }
}
