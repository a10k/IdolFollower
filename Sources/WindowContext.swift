import Foundation
import Combine

final class WindowContext: ObservableObject {
    let id: String
    @Published var modelURL: URL?
    @Published var baseRotX: Double
    @Published var baseRotY: Double
    @Published var baseRotZ: Double
    @Published var lockTilt: Bool
    @Published var lockSpin: Bool
    @Published var lockRoll: Bool
    @Published var ignoresMouse: Bool
    @Published var parallaxH: Double
    @Published var parallaxV: Double

    init(state: WindowState) {
        id = state.id
        baseRotX = state.baseRotX
        baseRotY = state.baseRotY
        baseRotZ = state.baseRotZ
        lockTilt = state.lockTilt
        lockSpin = state.lockSpin
        lockRoll = state.lockRoll
        ignoresMouse = state.ignoresMouse
        parallaxH = state.parallaxH
        parallaxV = state.parallaxV
        if let path = state.modelPath,
           FileManager.default.fileExists(atPath: path) {
            modelURL = URL(fileURLWithPath: path)
        }
    }
}
