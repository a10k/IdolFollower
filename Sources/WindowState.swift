import Foundation
import CoreGraphics

struct WindowState: Codable {
    var id: String
    var modelPath: String?
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var baseRotX: Double
    var baseRotY: Double
    var baseRotZ: Double = 0
    var lockTilt: Bool = false
    var lockSpin: Bool = false
    var lockRoll: Bool = false
    var ignoresMouse: Bool = false
    var parallaxH: Double = 1.0
    var parallaxV: Double = 1.0

    var frame: CGRect { CGRect(x: x, y: y, width: width, height: height) }
}
