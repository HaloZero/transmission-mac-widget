import AppKit
import SwiftUI
import WidgetKit

// Renders TransmissionWidgetView off-screen via ImageRenderer, using
// TorrentInfo.fixtures — no live widget host, no screen capture, no
// permissions. Run via `make screenshots`; see Scripts/render-screenshots.sh.

// Real macOS WidgetKit canvas sizes (Apple HIG), points.
let widgetSizes: [(family: WidgetFamily, size: CGSize, filename: String)] = [
    (.systemMedium, CGSize(width: 329, height: 155), "widget-medium.png"),
    (.systemLarge, CGSize(width: 329, height: 345), "widget-large.png")
]

@MainActor
func renderPNG(family: WidgetFamily, size: CGSize) -> Data? {
    let entry = TorrentEntry(date: Date(), rows: TorrentInfo.fixtures, errorMessage: nil)
    let view = TransmissionWidgetView(entry: entry, family: family)
        .frame(width: size.width, height: size.height)

    let renderer = ImageRenderer(content: view)
    renderer.scale = 2.0

    guard let nsImage = renderer.nsImage,
          let tiffData = nsImage.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData) else {
        return nil
    }
    return bitmap.representation(using: .png, properties: [:])
}

let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Screenshots"
let outputURL = URL(fileURLWithPath: outputDir)
try? FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

// main.swift top-level code runs on the main thread but isn't implicitly
// @MainActor-isolated, and ImageRenderer requires MainActor — this is a
// synchronous command-line tool with no other thread contending for it.
let failed = MainActor.assumeIsolated { () -> Bool in
    var anyFailed = false
    for (family, size, filename) in widgetSizes {
        let fileURL = outputURL.appendingPathComponent(filename)
        guard let pngData = renderPNG(family: family, size: size) else {
            print("error: failed to render \(filename)")
            anyFailed = true
            continue
        }
        do {
            try pngData.write(to: fileURL)
            print("Wrote \(fileURL.path)")
        } catch {
            print("error: failed to write \(fileURL.path): \(error)")
            anyFailed = true
        }
    }
    return anyFailed
}

exit(failed ? 1 : 0)
