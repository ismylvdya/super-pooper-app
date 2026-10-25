// Compares two folders of reference screenshots (scripts/snapshots.sh): same file names, pixel by pixel.
// Usage: swift scripts/compare-snapshots.swift <reference> <current> [<diff folder>]
// Prints every picture that differs in more than 0.05 % of its pixels; exit 1 if any does.
import AppKit
import CoreGraphics
import Foundation

func pixels(_ url: URL) -> (width: Int, height: Int, data: [UInt8])? {
    guard let image = NSImage(contentsOf: url)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
    let width = image.width, height = image.height
    var data = [UInt8](repeating: 0, count: width * height * 4)
    guard let context = CGContext(data: &data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return (width, height, data)
}

func writeDiff(_ data: [UInt8], width: Int, height: Int, to url: URL) {
    var copy = data
    guard let context = CGContext(data: &copy, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
          let image = context.makeImage() else { return }
    let rep = NSBitmapImageRep(cgImage: image)
    try? rep.representation(using: .png, properties: [:])?.write(to: url)
}

let arguments = CommandLine.arguments
guard arguments.count >= 3 else {
    print("usage: compare-snapshots.swift <reference> <current> [<diff folder>]")
    exit(2)
}
let reference = URL(fileURLWithPath: arguments[1]), current = URL(fileURLWithPath: arguments[2])
let diffFolder = arguments.count > 3 ? URL(fileURLWithPath: arguments[3]) : nil
let files = FileManager.default.enumerator(atPath: reference.path)?.compactMap { $0 as? String }.filter { $0.hasSuffix(".png") }.sorted() ?? []
var failed = 0
for file in files {
    let other = current.appendingPathComponent(file)
    guard let a = pixels(reference.appendingPathComponent(file)) else { continue }
    guard let b = pixels(other) else {
        print("MISSING  \(file)")
        failed += 1
        continue
    }
    guard a.width == b.width, a.height == b.height else {
        print("SIZE     \(file) \(a.width)x\(a.height) → \(b.width)x\(b.height)")
        failed += 1
        continue
    }
    var different = 0
    var diff = b.data
    for index in stride(from: 0, to: a.data.count, by: 4) {
        let delta = (0..<3).map { abs(Int(a.data[index + $0]) - Int(b.data[index + $0])) }.max() ?? 0
        if delta > 16 {
            different += 1
            diff[index] = 255; diff[index + 1] = 0; diff[index + 2] = 0; diff[index + 3] = 255
        }
    }
    let share = Double(different) / Double(a.width * a.height)
    if share > 0.0005 {
        print(String(format: "DIFF     %@ %.2f %%", file, share * 100))
        failed += 1
        if let diffFolder {
            let target = diffFolder.appendingPathComponent(file)
            try? FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            writeDiff(diff, width: b.width, height: b.height, to: target)
        }
    }
}
print("\(files.count) pictures, \(failed) differ")
exit(failed == 0 ? 0 : 1)
