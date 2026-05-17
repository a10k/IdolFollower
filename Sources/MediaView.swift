import Foundation

extension URL {
    static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "heic", "tiff", "bmp", "webp", "gif"]
    var isImageFile: Bool { URL.imageExtensions.contains(pathExtension.lowercased()) }
}
