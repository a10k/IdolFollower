import Foundation
import Combine

final class WindowContext: ObservableObject {
    let id: String
    @Published var modelURL: URL?
    @Published var baseRotX: Double
    @Published var baseRotY: Double

    init(state: WindowState) {
        id = state.id
        baseRotX = state.baseRotX
        baseRotY = state.baseRotY
        if let path = state.modelPath,
           FileManager.default.fileExists(atPath: path) {
            modelURL = URL(fileURLWithPath: path)
        }
    }
}
