import Foundation
import Combine

final class WindowContext: ObservableObject {
    let id: String
    @Published var modelURL: URL?
    private var securityScopedURL: URL?
    @Published var baseRotX: Double
    @Published var baseRotY: Double
    @Published var baseRotZ: Double
    @Published var lockTilt: Bool
    @Published var lockSpin: Bool
    @Published var ignoresMouse: Bool
    @Published var parallaxH: Double
    @Published var parallaxV: Double

    func stopModelAccess() {
        securityScopedURL?.stopAccessingSecurityScopedResource()
        securityScopedURL = nil
    }

    init(state: WindowState) {
        id = state.id
        baseRotX = state.baseRotX
        baseRotY = state.baseRotY
        baseRotZ = state.baseRotZ
        lockTilt = state.lockTilt
        lockSpin = state.lockSpin
        ignoresMouse = state.ignoresMouse
        parallaxH = state.parallaxH
        parallaxV = state.parallaxV
        if let bookmark = state.modelBookmark {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: bookmark,
                                  options: .withSecurityScope,
                                  relativeTo: nil,
                                  bookmarkDataIsStale: &stale) {
                if url.startAccessingSecurityScopedResource() {
                    securityScopedURL = url
                }
                modelURL = url
            }
        }
    }
}
