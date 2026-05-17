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

    init(state: WindowState) {
        id = state.id
        baseRotX = state.baseRotX
        baseRotY = state.baseRotY
        baseRotZ = state.baseRotZ
        lockTilt = state.lockTilt
        lockSpin = state.lockSpin
        lockRoll = state.lockRoll
        if let path = state.modelPath,
           FileManager.default.fileExists(atPath: path) {
            modelURL = URL(fileURLWithPath: path)
        }
    }
}
