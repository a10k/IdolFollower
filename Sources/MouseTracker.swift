import AppKit
import Combine

final class MouseTracker: ObservableObject {
    @Published var rotationX: Double = 0
    @Published var rotationY: Double = 0

    weak var window: NSWindow?
    private var timer: Timer?

    func startTracking() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.update()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stopTracking() {
        timer?.invalidate()
        timer = nil
    }

    private func update() {
        guard let window else { return }
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) }
            ?? window.screen
            ?? NSScreen.main
        guard let screen else { return }

        let dx = mouse.x - window.frame.midX
        let dy = mouse.y - window.frame.midY
        let maxAngle = 25.0
        rotationY =  (dx / (screen.frame.width  * 0.5)) * maxAngle
        rotationX = -(dy / (screen.frame.height * 0.5)) * maxAngle
    }
}
