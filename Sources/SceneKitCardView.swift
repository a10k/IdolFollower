import SwiftUI
import SceneKit

struct SceneKitView: NSViewRepresentable {
    @EnvironmentObject var tracker: MouseTracker
    @EnvironmentObject var windowContext: WindowContext
    var viewSize: CGSize
    var debug: DebugState

    // MARK: - Coordinator

    final class Coordinator: NSObject, SCNSceneRendererDelegate {
        var lastSize: CGSize = .zero
        var pendingFit = false
        var didInitialFit = false
        var lastModelURL: URL? = nil  // tracks what's currently loaded; avoids redundant reloads
        weak var sv: SCNView?
        var debug: DebugState?
        weak var windowContext: WindowContext?

        // Right-drag axis-lock state
        private enum DragAxis { case horizontal, vertical, diagonal }
        var isDragging = false
        private var dragAxisLock: DragAxis? = nil
        private var dragOrigin: CGPoint = .zero
        private var dragStartBaseX: Double = 0
        private var dragStartBaseY: Double = 0
        private var dragStartBaseZ: Double = 0
        private var dragDetectionDeadline: Date = .distantPast

        func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
            guard !didInitialFit, let sv, let debug else { return }
            didInitialFit = true
            DispatchQueue.main.async { SceneKitView.measureAndFit(in: sv, debug: debug) }
        }

        @objc func handlePinch(_ gr: NSMagnificationGestureRecognizer) {
            guard let window = sv?.window else { return }
            let scale = 1 + gr.magnification
            gr.magnification = 0
            resize(window, by: scale)
        }

        func beginBaseRotationDrag(at point: CGPoint) {
            dragOrigin = point
            dragStartBaseX = windowContext?.baseRotX ?? 0
            dragStartBaseY = windowContext?.baseRotY ?? 0
            dragStartBaseZ = windowContext?.baseRotZ ?? 0
            dragAxisLock = nil
            isDragging = true
            dragDetectionDeadline = Date().addingTimeInterval(1.0)
        }

        func updateBaseRotationDrag(to point: CGPoint) {
            let dx = Double(point.x - dragOrigin.x)
            let dy = Double(point.y - dragOrigin.y)

            if dragAxisLock == nil {
                guard Date() < dragDetectionDeadline else { return }
                guard max(abs(dx), abs(dy)) > 6 else { return }
                let ratio = abs(dx) / max(abs(dy), 0.001)
                if ratio > 2      { dragAxisLock = .horizontal }
                else if ratio < 0.5 { dragAxisLock = .vertical }
                else               { dragAxisLock = .diagonal }
            }

            switch dragAxisLock {
            case .horizontal:
                if !(windowContext?.lockSpin ?? false) {
                    windowContext?.baseRotY = dragStartBaseY + dx * 0.4
                }
            case .vertical:
                if !(windowContext?.lockTilt ?? false) {
                    windowContext?.baseRotX = dragStartBaseX - dy * 0.4
                }
            case .diagonal:
                if !(windowContext?.lockRoll ?? false) {
                    windowContext?.baseRotZ = dragStartBaseZ + dx * 0.4
                }
            case nil:
                break
            }
        }

        func endBaseRotationDrag() {
            isDragging = false
            dragAxisLock = nil
        }

        func resize(_ window: NSWindow, by scale: CGFloat) {
            let newW = (window.frame.width  * scale).clamped(to: 150...1200)
            let newH = (window.frame.height * scale).clamped(to: 150...1200)
            let cx = window.frame.midX, cy = window.frame.midY
            window.setFrame(CGRect(x: cx - newW/2, y: cy - newH/2, width: newW, height: newH), display: true)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    // MARK: - NSViewRepresentable

    func makeNSView(context: Context) -> SCNView {
        let coord = context.coordinator
        coord.windowContext = windowContext
        coord.lastModelURL = windowContext.modelURL  // prevent redundant reload on first updateNSView

        let sv = IdolSCNView(coordinator: coord)
        sv.scene = Self.makeScene(url: windowContext.modelURL)
        sv.backgroundColor = .clear
        sv.wantsLayer = true
        sv.layer?.backgroundColor = .clear
        sv.antialiasingMode = .multisampling4X
        sv.allowsCameraControl = false
        sv.rendersContinuously = windowContext.modelURL?.pathExtension.lowercased() == "gif"

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
        let coord = context.coordinator
        coord.windowContext = windowContext

        // Reload scene when the model URL changes
        let newURL = windowContext.modelURL
        if newURL != coord.lastModelURL {
            coord.lastModelURL = newURL
            let scene = Self.makeScene(url: newURL)
            sv.scene = scene
            sv.rendersContinuously = newURL?.pathExtension.lowercased() == "gif"
            if let cam = scene.rootNode.childNode(withName: "camera", recursively: false) {
                sv.pointOfView = cam
            }
            coord.pendingFit = false
            let dbg = debug
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                SceneKitView.measureAndFit(in: sv, debug: dbg)
            }
        }

        // Apply rotation — freeze parallax while right-dragging or axis is locked
        if let model = sv.scene?.rootNode.childNode(withName: "model", recursively: false) {
            let parallaxX = (coord.isDragging || windowContext.lockTilt) ? 0.0 : tracker.rotationX * windowContext.parallaxV
            let parallaxY = (coord.isDragging || windowContext.lockSpin) ? 0.0 : tracker.rotationY * windowContext.parallaxH
            let xr = Float((windowContext.baseRotX + parallaxX) * .pi / 180)
            let yr = Float((windowContext.baseRotY + parallaxY) * .pi / 180)
            let zr = Float(windowContext.baseRotZ * .pi / 180)
            SCNTransaction.begin()
            SCNTransaction.animationDuration = coord.isDragging ? 0 : 0.12
            model.eulerAngles = SCNVector3(xr, yr, zr)
            SCNTransaction.commit()
        }

        // Re-fit camera when window is resized
        if viewSize != coord.lastSize {
            coord.lastSize = viewSize
            guard !coord.pendingFit else { return }
            coord.pendingFit = true
            let dbg = debug
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                coord.pendingFit = false
                SceneKitView.measureAndFit(in: sv, debug: dbg)
            }
        }
    }

    // MARK: - Silhouette fit
    //
    // Snapshot with a black background, scan for non-black pixels to find the
    // model's screen-space silhouette, then move the camera so the enclosing
    // circle fills the shorter viewport dimension.

    static func measureAndFit(in sv: SCNView, debug: DebugState) {
        guard sv.bounds.width > 0, sv.bounds.height > 0,
              let camNode = sv.scene?.rootNode.childNode(withName: "camera", recursively: false)
        else { return }

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
                    guard Int(r) + Int(g) + Int(b) > 24 else { continue }
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

        guard minX < maxX, minY < maxY else { return }

        // Snapshot is device pixels; sv.bounds is points.
        let px = sv.window?.backingScaleFactor ?? 1.0
        let center = CGPoint(x: sv.bounds.midX, y: sv.bounds.midY)
        let corners: [CGPoint] = [
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
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue)
            if let provider = CGDataProvider(data: Data(maskBytes) as CFData),
               let maskCG = CGImage(width: imgW, height: imgH,
                                    bitsPerComponent: 8, bitsPerPixel: 32,
                                    bytesPerRow: imgW * 4,
                                    space: colorSpace, bitmapInfo: bitmapInfo,
                                    provider: provider, decode: nil,
                                    shouldInterpolate: false, intent: .defaultIntent) {
                debug.maskImage = NSImage(cgImage: maskCG,
                                         size: NSSize(width: CGFloat(imgW)/px, height: CGFloat(imgH)/px))
            }
            debug.circleCenter = center
            debug.circleRadius = radius
        }
    }

    // MARK: - Scene

    static func makeScene(url: URL?) -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = NSColor.clear

        scene.rootNode.addChildNode(ambientLight(intensity: 450))
        scene.rootNode.addChildNode(directionalLight(intensity: 1000, euler: SCNVector3(-0.5, 0.4, 0)))
        scene.rootNode.addChildNode(directionalLight(intensity: 300,
                                                     color: NSColor(red: 0.7, green: 0.8, blue: 1, alpha: 1),
                                                     euler: SCNVector3(0.2, -1.2, 0)))

        let model = SCNNode()
        model.name = "model"

        let loaded: Bool
        if let url, url.isImageFile {
            if let planeNode = imagePlane(from: url) {
                model.addChildNode(planeNode)
                normalizeModel(model)
                loaded = true
            } else {
                loaded = false
            }
        } else if let url,
                  FileManager.default.fileExists(atPath: url.path),
                  let source = try? SCNScene(url: url, options: [.checkConsistency: false]) {
            source.rootNode.childNodes.forEach { model.addChildNode($0) }
            normalizeModel(model)
            loaded = true
        } else {
            loaded = false
        }

        if !loaded {
            let pyramid = SCNPyramid(width: 1.4, height: 1.8, length: 1.4)
            pyramid.firstMaterial?.diffuse.contents = NSColor.systemIndigo
            model.addChildNode(SCNNode(geometry: pyramid))
        }

        scene.rootNode.addChildNode(model)
        scene.rootNode.addChildNode(camera())
        return scene
    }

    private static func ambientLight(intensity: CGFloat) -> SCNNode {
        let light = SCNLight()
        light.type = .ambient
        light.intensity = intensity
        let node = SCNNode()
        node.light = light
        return node
    }

    private static func directionalLight(intensity: CGFloat,
                                          color: NSColor = .white,
                                          euler: SCNVector3 = .init(0, 0, 0)) -> SCNNode {
        let light = SCNLight()
        light.type = .directional
        light.intensity = intensity
        light.color = color
        let node = SCNNode()
        node.light = light
        node.eulerAngles = euler
        return node
    }

    private static func camera() -> SCNNode {
        let cam = SCNCamera()
        cam.fieldOfView = 40
        cam.zNear = 0.01
        let node = SCNNode()
        node.name = "camera"
        node.camera = cam
        node.position = SCNVector3(0, 0, 4)
        return node
    }

    private static func normalizeModel(_ node: SCNNode) {
        let (mn, mx) = node.boundingBox
        let dx = Float(mx.x - mn.x), dy = Float(mx.y - mn.y), dz = Float(mx.z - mn.z)
        guard dx > 0 || dy > 0 || dz > 0 else { return }
        let scale = 2.0 / max(dx, dy, dz)
        node.pivot = SCNMatrix4MakeTranslation((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, (mn.z + mx.z) / 2)
        node.scale = SCNVector3(scale, scale, scale)
        node.position = SCNVector3(0, 0, 0)
    }

    // MARK: - Image / GIF plane

    private static func imagePlane(from url: URL) -> SCNNode? {
        guard let image = NSImage(contentsOf: url) else { return nil }
        let sz = image.size
        guard sz.width > 0, sz.height > 0 else { return nil }

        let plane = SCNPlane(width: sz.width / sz.height, height: 1)
        let mat = SCNMaterial()
        mat.lightingModel = .constant   // unlit — don't let directional lights shade the image
        mat.isDoubleSided = true

        if url.pathExtension.lowercased() == "gif", let layer = makeGifLayer(from: image) {
            mat.diffuse.contents = layer
        } else {
            mat.diffuse.contents = image
        }

        plane.materials = [mat]
        return SCNNode(geometry: plane)
    }

    // Build a CALayer whose `contents` CAKeyframeAnimation cycles through GIF frames.
    // SceneKit samples the layer's presentation state each render pass.
    private static func makeGifLayer(from image: NSImage) -> CALayer? {
        guard let rep = image.representations.compactMap({ $0 as? NSBitmapImageRep }).first,
              let count = rep.value(forProperty: .frameCount) as? Int,
              count > 1 else { return nil }

        var cgFrames: [CGImage] = []
        var durations: [Double] = []

        for i in 0..<count {
            rep.setProperty(.currentFrame, withValue: NSNumber(value: i))
            let dur = (rep.value(forProperty: .currentFrameDuration) as? Double) ?? 0.1
            guard let cg = rep.cgImage else { continue }
            cgFrames.append(cg)
            durations.append(dur)
        }

        guard !cgFrames.isEmpty else { return nil }

        let total = durations.reduce(0, +)
        var cumulative = 0.0
        var keyTimes: [NSNumber] = []
        for dur in durations {
            keyTimes.append(NSNumber(value: cumulative / total))
            cumulative += dur
        }

        let layer = CALayer()
        layer.frame = CGRect(origin: .zero, size: image.size)
        layer.contents = cgFrames.first

        let anim = CAKeyframeAnimation(keyPath: "contents")
        anim.values = cgFrames
        anim.keyTimes = keyTimes
        anim.duration = total
        anim.repeatCount = .infinity
        anim.calculationMode = .discrete   // jump between frames, no interpolation
        layer.add(anim, forKey: "gif")

        return layer
    }
}

// MARK: - SCNView subclass

private final class IdolSCNView: SCNView {
    weak var coordinator: SceneKitView.Coordinator?

    init(coordinator: SceneKitView.Coordinator) {
        self.coordinator = coordinator
        super.init(frame: .zero, options: nil)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        // Trigger a SceneKit render pass so newly-exposed pixels aren't left black
        needsDisplay = true
    }

    override func scrollWheel(with event: NSEvent) {
        guard let window, let coord = coordinator else { return }
        let delta = event.hasPreciseScrollingDeltas
            ? event.scrollingDeltaY * 0.004
            : event.scrollingDeltaY * 0.04
        coord.resize(window, by: 1 + delta)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeKeyAndOrderFront(nil)
        super.mouseDown(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        window?.makeKeyAndOrderFront(nil)
        coordinator?.beginBaseRotationDrag(at: event.locationInWindow)
    }

    override func rightMouseDragged(with event: NSEvent) {
        coordinator?.updateBaseRotationDrag(to: event.locationInWindow)
    }

    override func rightMouseUp(with event: NSEvent) {
        coordinator?.endBaseRotationDrag()
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
