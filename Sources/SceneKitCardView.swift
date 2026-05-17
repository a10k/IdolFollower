import SwiftUI
import SceneKit
import GLTFKit2

struct SceneKitView: NSViewRepresentable {
    @EnvironmentObject var tracker: MouseTracker
    var viewSize: CGSize
    var debug: DebugState

    // MARK: - Coordinator

    class Coordinator: NSObject, SCNSceneRendererDelegate {
        var lastSize: CGSize = .zero
        var pendingFit = false
        var didInitialFit = false
        weak var sv: SCNView?
        var debug: DebugState?
        weak var tracker: MouseTracker?

        // Right-drag base rotation state
        private var dragOrigin: CGPoint = .zero
        private var dragStartBaseX: Double = 0
        private var dragStartBaseY: Double = 0

        func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
            guard !didInitialFit, let sv, let dbg = debug else { return }
            didInitialFit = true
            DispatchQueue.main.async { SceneKitView.measureAndFit(in: sv, debug: dbg) }
        }

        func startObservingModelChanges() {
            NotificationCenter.default.addObserver(self, selector: #selector(reloadModel(_:)),
                                                   name: .modelURLChanged, object: nil)
        }

        @objc func reloadModel(_ note: Notification) {
            guard let url = note.object as? URL, let sv = sv, let dbg = debug else { return }
            let scene = SceneKitView.makeScene(url: url)
            sv.scene = scene
            if let cam = scene.rootNode.childNode(withName: "camera", recursively: false) {
                sv.pointOfView = cam
            }
            didInitialFit = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                SceneKitView.measureAndFit(in: sv, debug: dbg)
            }
        }

        @objc func handlePinch(_ gr: NSMagnificationGestureRecognizer) {
            guard let window = sv?.window else { return }
            let scale = 1 + gr.magnification
            gr.magnification = 0
            resizeWindow(window, by: scale)
        }

        func beginBaseRotationDrag(at point: CGPoint) {
            dragOrigin = point
            dragStartBaseX = tracker?.baseRotationX ?? 0
            dragStartBaseY = tracker?.baseRotationY ?? 0
        }

        func updateBaseRotationDrag(to point: CGPoint) {
            let dx = Double(point.x - dragOrigin.x)
            let dy = Double(point.y - dragOrigin.y)
            tracker?.baseRotationY = dragStartBaseY + dx * 0.4
            tracker?.baseRotationX = dragStartBaseX - dy * 0.4
        }

        func resizeWindow(_ window: NSWindow, by scale: CGFloat) {
            let minSide: CGFloat = 150
            let maxSide: CGFloat = 1200
            let newW = (window.frame.width  * scale).clamped(to: minSide...maxSide)
            let newH = (window.frame.height * scale).clamped(to: minSide...maxSide)
            let cx = window.frame.midX, cy = window.frame.midY
            window.setFrame(CGRect(x: cx - newW/2, y: cy - newH/2, width: newW, height: newH), display: true)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    // MARK: - NSViewRepresentable

    func makeNSView(context: Context) -> SCNView {
        let coord = context.coordinator
        coord.tracker = tracker
        coord.startObservingModelChanges()
        let sv = IdolSCNView(coordinator: coord)
        sv.scene = Self.makeScene(url: Self.savedModelURL())
        sv.backgroundColor = .clear
        sv.antialiasingMode = .multisampling4X
        sv.allowsCameraControl = false
        sv.rendersContinuously = false

        if let cam = sv.scene?.rootNode.childNode(withName: "camera", recursively: false) {
            sv.pointOfView = cam
        }

        coord.sv = sv
        coord.debug = debug
        coord.lastSize = viewSize
        sv.delegate = coord

        let pinch = NSMagnificationGestureRecognizer(target: coord, action: #selector(Coordinator.handlePinch(_:)))
        sv.addGestureRecognizer(pinch)

        return sv
    }

    func updateNSView(_ sv: SCNView, context: Context) {
        if let model = sv.scene?.rootNode.childNode(withName: "model", recursively: false) {
            let xr = Float((tracker.baseRotationX + tracker.rotationX) * .pi / 180)
            let yr = Float((tracker.baseRotationY + tracker.rotationY) * .pi / 180)
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.12
            model.eulerAngles = SCNVector3(xr, yr, 0)
            SCNTransaction.commit()
        }

        let coord = context.coordinator
        let dbg = debug
        if viewSize.width != coord.lastSize.width || viewSize.height != coord.lastSize.height {
            coord.lastSize = viewSize
            guard !coord.pendingFit else { return }
            coord.pendingFit = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                coord.pendingFit = false
                SceneKitView.measureAndFit(in: sv, debug: dbg)
            }
        }
    }

    // MARK: - Silhouette fit
    //
    // Snapshot against black, scan for non-black pixels to find the exact
    // screen-space silhouette, then move the camera so the enclosing circle
    // (centred at the projected model origin, radius = farthest bbox corner)
    // fits within the shorter viewport dimension.

    static func measureAndFit(in sv: SCNView, debug: DebugState) {
        guard let camNode = sv.scene?.rootNode.childNode(withName: "camera", recursively: false),
              sv.bounds.width > 0, sv.bounds.height > 0 else { return }

        let origBg = sv.scene?.background.contents
        sv.scene?.background.contents = NSColor.black
        let snap = sv.snapshot()
        sv.scene?.background.contents = origBg

        guard let cg = snap.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let cfdata = cg.dataProvider?.data else { return }

        let imgW = cg.width, imgH = cg.height
        let bpp = cg.bitsPerPixel / 8
        let bpr = cg.bytesPerRow
        let data = cfdata as Data

        var minX = imgW, maxX = 0, minY = imgH, maxY = 0
        var maskBytes = kDebugOverlay ? [UInt8](repeating: 0, count: imgW * imgH * 4) : []

        data.withUnsafeBytes { raw in
            for y in 0..<imgH {
                for x in 0..<imgW {
                    let src = y * bpr + x * bpp
                    guard src + 2 < data.count else { continue }
                    let r = raw.load(fromByteOffset: src,     as: UInt8.self)
                    let g = raw.load(fromByteOffset: src + 1, as: UInt8.self)
                    let b = raw.load(fromByteOffset: src + 2, as: UInt8.self)
                    if Int(r) + Int(g) + Int(b) > 24 {
                        if x < minX { minX = x }; if x > maxX { maxX = x }
                        if y < minY { minY = y }; if y > maxY { maxY = y }
                        if kDebugOverlay {
                            let dst = (y * imgW + x) * 4
                            maskBytes[dst] = 255; maskBytes[dst+1] = 220
                            maskBytes[dst+2] = 0;  maskBytes[dst+3] = 160
                        }
                    }
                }
            }
        }

        guard minX < maxX, minY < maxY else { return }

        // Snapshot is in device pixels; sv.bounds is in points.
        let px = sv.window?.backingScaleFactor ?? 1.0
        let center = CGPoint(x: sv.bounds.midX, y: sv.bounds.midY)
        let corners = [
            CGPoint(x: CGFloat(minX)/px, y: CGFloat(minY)/px),
            CGPoint(x: CGFloat(maxX)/px, y: CGFloat(minY)/px),
            CGPoint(x: CGFloat(minX)/px, y: CGFloat(maxY)/px),
            CGPoint(x: CGFloat(maxX)/px, y: CGFloat(maxY)/px),
        ]
        let radius = corners.map { hypot($0.x - center.x, $0.y - center.y) }.max() ?? 0
        guard radius > 0 else { return }

        let maxFit = min(sv.bounds.width, sv.bounds.height) / 2
        let newZ = Float(camNode.position.z) * Float(radius / maxFit)
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0
        camNode.position = SCNVector3(0, 0, newZ)
        SCNTransaction.commit()

        if kDebugOverlay {
            let cs = CGColorSpaceCreateDeviceRGB()
            let bi = CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue)
            if let prov = CGDataProvider(data: Data(maskBytes) as CFData),
               let maskCG = CGImage(width: imgW, height: imgH, bitsPerComponent: 8, bitsPerPixel: 32,
                                    bytesPerRow: imgW * 4, space: cs, bitmapInfo: bi,
                                    provider: prov, decode: nil, shouldInterpolate: false, intent: .defaultIntent) {
                debug.maskImage = NSImage(cgImage: maskCG, size: NSSize(width: CGFloat(imgW)/px, height: CGFloat(imgH)/px))
            }
            debug.circleCenter = center
            debug.circleRadius = radius
        }
    }

    // MARK: - Scene

    static func savedModelURL() -> URL {
        if let path = UserDefaults.standard.string(forKey: "modelPath") {
            return URL(fileURLWithPath: path)
        }
        return URL(fileURLWithPath: "/Users/studio257/Downloads/Frank.usdz")
    }

    static func makeScene(url: URL) -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = NSColor.clear

        let al = SCNNode(); al.light = { let l = SCNLight(); l.type = .ambient; l.intensity = 450; return l }()
        let kl = SCNNode(); kl.light = { let l = SCNLight(); l.type = .directional; l.intensity = 1000; return l }(); kl.eulerAngles = SCNVector3(-0.5, 0.4, 0)
        let fl = SCNNode(); fl.light = { let l = SCNLight(); l.type = .directional; l.intensity = 300; l.color = NSColor(red: 0.7, green: 0.8, blue: 1, alpha: 1); return l }(); fl.eulerAngles = SCNVector3(0.2, -1.2, 0)
        for n in [al, kl, fl] { scene.rootNode.addChildNode(n) }

        let model = SCNNode(); model.name = "model"
        let ext = url.pathExtension.lowercased()
        var loaded = false

        if ext == "gltf" || ext == "glb" {
            if let asset = try? GLTFAsset(url: url) {
                let source = GLTFSCNSceneSource(asset: asset)
                if let ms = source.defaultScene {
                    for child in ms.rootNode.childNodes { model.addChildNode(child) }
                    normalizeModel(model)
                    loaded = true
                }
            }
        } else {
            if let ms = try? SCNScene(url: url, options: [.checkConsistency: false]) {
                for child in ms.rootNode.childNodes { model.addChildNode(child) }
                normalizeModel(model)
                loaded = true
            }
        }

        if !loaded {
            let g = SCNPyramid(width: 1.4, height: 1.8, length: 1.4)
            g.firstMaterial?.diffuse.contents = NSColor.systemIndigo
            model.addChildNode(SCNNode(geometry: g))
        }
        scene.rootNode.addChildNode(model)

        let cam = SCNNode(); cam.name = "camera"; cam.camera = SCNCamera()
        cam.camera!.fieldOfView = 40
        cam.camera!.zNear = 0.01
        cam.position = SCNVector3(0, 0, 4)
        scene.rootNode.addChildNode(cam)
        return scene
    }

    private static func normalizeModel(_ node: SCNNode) {
        let (mn, mx) = node.boundingBox
        let dx = Float(mx.x - mn.x), dy = Float(mx.y - mn.y), dz = Float(mx.z - mn.z)
        guard dx > 0 || dy > 0 || dz > 0 else { return }
        let s = 2.0 / max(dx, dy, dz)
        node.pivot = SCNMatrix4MakeTranslation((mn.x+mx.x)/2, (mn.y+mx.y)/2, (mn.z+mx.z)/2)
        node.scale = SCNVector3(s, s, s)
        node.position = SCNVector3(0, 0, 0)
    }
}

// MARK: - SCNView subclass for scroll-wheel zoom

private class IdolSCNView: SCNView {
    weak var coordinator: SceneKitView.Coordinator?

    init(coordinator: SceneKitView.Coordinator) {
        self.coordinator = coordinator
        super.init(frame: .zero, options: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func scrollWheel(with event: NSEvent) {
        guard let window, let coord = coordinator else { return }
        let delta = event.hasPreciseScrollingDeltas
            ? event.scrollingDeltaY * 0.004
            : event.scrollingDeltaY * 0.04
        coord.resizeWindow(window, by: 1 + delta)
    }

    override func rightMouseDown(with event: NSEvent) {
        coordinator?.beginBaseRotationDrag(at: event.locationInWindow)
    }

    override func rightMouseDragged(with event: NSEvent) {
        coordinator?.updateBaseRotationDrag(to: event.locationInWindow)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
