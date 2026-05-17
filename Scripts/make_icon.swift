#!/usr/bin/env swift
// Renders an SF Symbol into an .icns file for the app bundle.
import AppKit
import Foundation

let _ = NSApplication.shared  // required for SF Symbol access

let symbolName = "cube.transparent"
let iconsetDir = "/tmp/IdolFollower.iconset"

try? FileManager.default.removeItem(atPath: iconsetDir)
try! FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

func makePNG(size: Int) -> Data? {
    let s = CGFloat(size)

    guard let bmp = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .calibratedRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    ) else { return nil }

    NSGraphicsContext.saveGraphicsState()
    guard let ctx = NSGraphicsContext(bitmapImageRep: bmp) else {
        NSGraphicsContext.restoreGraphicsState()
        return nil
    }
    NSGraphicsContext.current = ctx

    let rect = NSRect(x: 0, y: 0, width: s, height: s)

    // Indigo gradient rounded background
    let bg = NSGradient(
        starting: NSColor(red: 0.28, green: 0.15, blue: 0.88, alpha: 1),
        ending:   NSColor(red: 0.12, green: 0.05, blue: 0.52, alpha: 1)
    )!
    bg.draw(in: NSBezierPath(roundedRect: rect, xRadius: s * 0.22, yRadius: s * 0.22), angle: -90)

    // SF Symbol in white
    let config = NSImage.SymbolConfiguration(pointSize: s * 0.48, weight: .light)
        .applying(NSImage.SymbolConfiguration(hierarchicalColor: .white))

    if let sym = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        sym.draw(in: NSRect(
            x: (s - sym.size.width)  / 2,
            y: (s - sym.size.height) / 2,
            width:  sym.size.width,
            height: sym.size.height
        ))
    }

    NSGraphicsContext.restoreGraphicsState()
    return bmp.representation(using: .png, properties: [:])
}

let entries: [(Int, String)] = [
    (16,   "icon_16x16"),
    (32,   "icon_16x16@2x"),
    (32,   "icon_32x32"),
    (64,   "icon_32x32@2x"),
    (128,  "icon_128x128"),
    (256,  "icon_128x128@2x"),
    (256,  "icon_256x256"),
    (512,  "icon_256x256@2x"),
    (512,  "icon_512x512"),
    (1024, "icon_512x512@2x"),
]

for (size, name) in entries {
    if let data = makePNG(size: size) {
        try! data.write(to: URL(fileURLWithPath: "\(iconsetDir)/\(name).png"))
        print("  \(name).png")
    } else {
        fputs("  failed: \(name)\n", stderr)
        exit(1)
    }
}
