import AppKit
import Combine

class MouseTracker: ObservableObject {
    // Live parallax driven by mouse position
    @Published var rotationX: Double = 0
    @Published var rotationY: Double = 0

    // Persistent base orientation set via right-drag
    @Published var baseRotationX: Double = UserDefaults.standard.double(forKey: "baseRotX") {
        didSet { UserDefaults.standard.set(baseRotationX, forKey: "baseRotX") }
    }
    @Published var baseRotationY: Double = UserDefaults.standard.double(forKey: "baseRotY") {
        didSet { UserDefaults.standard.set(baseRotationY, forKey: "baseRotY") }
    }

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
        guard let screen = NSScreen.main, let window = window else { return }
        let mouse = NSEvent.mouseLocation
        let dx = mouse.x - window.frame.midX
        let dy = mouse.y - window.frame.midY
        let maxAngle = 25.0
        rotationY =  (dx / (screen.frame.width  * 0.5)) * maxAngle
        rotationX = -(dy / (screen.frame.height * 0.5)) * maxAngle
    }
}
