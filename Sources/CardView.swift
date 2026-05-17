import SwiftUI
import AppKit

let kDebugOverlay = false

class DebugState: ObservableObject {
    @Published var maskImage: NSImage? = nil
    @Published var circleCenter: CGPoint? = nil
    @Published var circleRadius: CGFloat = 0
}

struct RootView: View {
    @EnvironmentObject var tracker: MouseTracker
    @StateObject var debug = DebugState()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                SceneKitView(viewSize: geo.size, debug: debug)

                if kDebugOverlay {
                    Canvas { ctx, size in
                        if let img = debug.maskImage {
                            let resolved = ctx.resolve(Image(nsImage: img))
                            ctx.draw(resolved, in: CGRect(origin: .zero, size: size))
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
