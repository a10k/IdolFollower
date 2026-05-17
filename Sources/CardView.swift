import SwiftUI
import AppKit

let kDebugOverlay = false

final class DebugState: ObservableObject {
    @Published var maskImage: NSImage?
    @Published var circleCenter: CGPoint?
    @Published var circleRadius: CGFloat = 0
}

struct RootView: View {
    @StateObject private var debug = DebugState()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                SceneKitView(viewSize: geo.size, debug: debug)

                if kDebugOverlay {
                    Canvas { ctx, _ in
                        if let img = debug.maskImage {
                            ctx.draw(Image(nsImage: img), in: CGRect(origin: .zero, size: geo.size))
                        }
                        if let c = debug.circleCenter, debug.circleRadius > 0 {
                            let r = debug.circleRadius
                            ctx.stroke(
                                Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                                with: .color(.yellow),
                                lineWidth: 2
                            )
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
        }
        .ignoresSafeArea()
    }
}
