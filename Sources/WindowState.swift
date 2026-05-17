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

    var frame: CGRect { CGRect(x: x, y: y, width: width, height: height) }
}
