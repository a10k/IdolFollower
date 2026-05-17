import AppKit
import SwiftUI
import Combine

final class WindowManager: NSObject {
    static let shared = WindowManager()
    private override init() {}

    private struct Entry {
        let window: NSWindow
        let context: WindowContext
        let tracker: MouseTracker
    }

    private var entries: [String: Entry] = [:]
    private var contextCancellables: [String: AnyCancellable] = [:]
    private var saveWorkItem: DispatchWorkItem?

    private static let defaultsKey = "windowStates_v1"
    private static let defaultSize = CGSize(width: 320, height: 420)

    // MARK: - Public

    func restoreOrCreate() {
        let states = loadStates()
        if states.isEmpty {
            open(state: defaultState())
        } else {
            states.forEach { open(state: $0) }
        }
    }

    func openNewWindow() {
        open(state: defaultState())
    }

    func changeModel(for window: NSWindow) {
        guard let entry = entry(for: window) else { return }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.prompt = "Open"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        entry.context.modelURL = url
    }

    func saveAll() {
        saveWorkItem?.cancel()
        persist()
    }

    // MARK: - Private

    private func open(state: WindowState) {
        let context = WindowContext(state: state)
        let tracker = MouseTracker()
        let window = buildWindow(frame: clamped(state.frame))

        let rootView = RootView()
            .environmentObject(tracker)
            .environmentObject(context)
        window.contentView = NSHostingView(rootView: rootView)
        window.delegate = self
        tracker.window = window
        tracker.startTracking()
        window.makeKeyAndOrderFront(nil)

        let id = state.id
        entries[id] = Entry(window: window, context: context, tracker: tracker)

        contextCancellables[id] = context.objectWillChange
            .debounce(for: .seconds(0.3), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.scheduleSave() }
    }

    private func buildWindow(frame: CGRect) -> NSWindow {
        let window = NSWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        return window
    }

    private func defaultState() -> WindowState {
        let size = WindowManager.defaultSize
        let vis = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1280, height: 800)
        return WindowState(
            id: UUID().uuidString,
            modelPath: nil,
            x: vis.midX - size.width / 2,
            y: vis.midY - size.height / 2,
            width: size.width,
            height: size.height,
            baseRotX: 0,
            baseRotY: 0
        )
    }

    /// Constrains a proposed frame to a visible screen, falling back to main screen.
    private func clamped(_ frame: CGRect) -> CGRect {
        let screen = NSScreen.screens.first { $0.visibleFrame.intersects(frame) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let vis = screen?.visibleFrame else { return frame }
        var f = frame
        f.size.width  = max(150, min(f.size.width,  vis.width))
        f.size.height = max(150, min(f.size.height, vis.height))
        f.origin.x = max(vis.minX, min(f.origin.x, vis.maxX - f.size.width))
        f.origin.y = max(vis.minY, min(f.origin.y, vis.maxY - f.size.height))
        return f
    }

    private func entry(for window: NSWindow) -> Entry? {
        entries.values.first { $0.window === window }
    }

    private func scheduleSave() {
        saveWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.persist() }
        saveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: item)
    }

    private func persist() {
        let states: [WindowState] = entries.values.map { e in
            WindowState(
                id: e.context.id,
                modelPath: e.context.modelURL?.path,
                x: e.window.frame.origin.x,
                y: e.window.frame.origin.y,
                width: e.window.frame.width,
                height: e.window.frame.height,
                baseRotX: e.context.baseRotX,
                baseRotY: e.context.baseRotY
            )
        }
        if let data = try? JSONEncoder().encode(states) {
            UserDefaults.standard.set(data, forKey: WindowManager.defaultsKey)
        }
    }

    private func loadStates() -> [WindowState] {
        guard let data = UserDefaults.standard.data(forKey: WindowManager.defaultsKey),
              let states = try? JSONDecoder().decode([WindowState].self, from: data) else {
            return []
        }
        return states
    }
}

// MARK: - NSWindowDelegate

extension WindowManager: NSWindowDelegate {
    func windowDidMove(_ notification: Notification) { scheduleSave() }
    func windowDidResize(_ notification: Notification) { scheduleSave() }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              let id = entries.first(where: { $0.value.window === window })?.key else { return }
        entries[id]?.tracker.stopTracking()
        contextCancellables.removeValue(forKey: id)
        entries.removeValue(forKey: id)
        persist()
        if entries.isEmpty { NSApp.terminate(nil) }
    }
}
