import CoreGraphics
import Foundation
import ImageIO
import MoonRenderCore
import UniformTypeIdentifiers

// moonrender <out-dir> [--size 256] [--step 5]
// Writes one imageset per elongation step: <out-dir>/moon-EEE.imageset/{moon-EEE.png, Contents.json}.
// moonrender icon <AppIcon.appiconset>
// Writes the macOS app icon (a waxing crescent on the widget's night gradient) at every size, plus Contents.json.

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("moonrender: \(message)\n".utf8))
    exit(1)
}

var args = Array(CommandLine.arguments.dropFirst())
var size = 256, step = 5
var outDir: String?
var iconMode = false
while !args.isEmpty {
    let a = args.removeFirst()
    switch a {
    case "--size": guard let v = Int(args.isEmpty ? "" : args.removeFirst()) else { fail("--size needs an integer") }; size = v
    case "--step": guard let v = Int(args.isEmpty ? "" : args.removeFirst()) else { fail("--step needs an integer") }; step = v
    case "icon" where outDir == nil && !iconMode: iconMode = true
    default: if outDir == nil { outDir = a } else { fail("unexpected argument \(a)") }
    }
}
guard let outDir, size > 8, step > 0, 360 % step == 0 else {
    fail("usage: moonrender <out-dir> [--size 256] [--step 5]  (step must divide 360)\n"
         + "       moonrender icon <AppIcon.appiconset>")
}

let nasa = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("nasa")
func load(_ name: String) -> CGImage {
    guard let src = CGImageSourceCreateWithURL(nasa.appendingPathComponent(name) as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(src, 0, nil) else { fail("cannot read \(name)") }
    return image
}
let renderer = Renderer(colorMap: load("lroc_color_2k.jpg"), heightMap: load("ldem_4_uint.tif"))

let fm = FileManager.default
let root = URL(fileURLWithPath: outDir)
try fm.createDirectory(at: root, withIntermediateDirectories: true)

func writePNG(_ image: CGImage, to url: URL) {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { fail("cannot write \(url.path)") }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else { fail("cannot write \(url.path)") }
}

func bitmap(_ size: Int) -> CGContext {
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    return ctx
}

if iconMode {
    // Apple's macOS icon grid: 824 px rounded-rect body centred on the 1024 canvas, 185 px corners, drop shadow.
    let canvas = 1024.0, body = 824.0, corner = 185.0
    let elongation = 60.0, moonFraction = 0.62  // waxing crescent, lit on the right; moon diameter / body
    let master = bitmap(Int(canvas))
    let rect = CGRect(x: (canvas - body) / 2, y: (canvas - body) / 2 + 10, width: body, height: body)
    let shape = CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil)
    master.saveGState()
    master.setShadow(offset: CGSize(width: 0, height: -10), blur: 28, color: CGColor(gray: 0, alpha: 0.5))
    master.addPath(shape)
    master.setFillColor(CGColor(gray: 0, alpha: 1))
    master.fillPath()
    master.restoreGState()
    master.addPath(shape)
    master.clip()
    // Same gradient as NightBackground (Shared/NightWidgetView.swift), top to bottom.
    let night = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                           colors: [CGColor(srgbRed: 0.05, green: 0.07, blue: 0.16, alpha: 1),
                                    CGColor(srgbRed: 0.01, green: 0.02, blue: 0.06, alpha: 1)] as CFArray,
                           locations: [0, 1])!
    master.drawLinearGradient(night, start: CGPoint(x: rect.midX, y: rect.maxY),
                              end: CGPoint(x: rect.midX, y: rect.minY), options: [])
    // Brighter than the widget frames and with stronger earthshine, so the crescent and the dark limb still read at 32 px.
    var iconRenderer = renderer
    iconRenderer.exposure = 0.8
    iconRenderer.maxEarthshine = 0.01
    let moonSize = (body * moonFraction).rounded()
    master.draw(iconRenderer.render(elongation: elongation, size: Int(moonSize) * 2),
                in: CGRect(x: rect.midX - moonSize / 2, y: rect.midY - moonSize / 2, width: moonSize, height: moonSize))
    let icon = master.makeImage()!

    var entries: [String] = []
    for points in [16, 32, 128, 256, 512] {
        for scale in [1, 2] {
            let px = points * scale
            let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
            let ctx = bitmap(px)
            ctx.draw(icon, in: CGRect(x: 0, y: 0, width: px, height: px))
            writePNG(ctx.makeImage()!, to: root.appendingPathComponent(name))
            entries.append("    { \"filename\" : \"\(name)\", \"idiom\" : \"mac\", \"scale\" : \"\(scale)x\", "
                           + "\"size\" : \"\(points)x\(points)\" }")
        }
    }
    let json = "{\n  \"images\" : [\n" + entries.joined(separator: ",\n")
        + "\n  ],\n  \"info\" : { \"author\" : \"xcode\", \"version\" : 1 }\n}\n"
    try Data(json.utf8).write(to: root.appendingPathComponent("Contents.json"))
    print("moonrender: app icon, elongation \(Int(elongation))°, in \(root.path)")
    exit(0)
}
let catalog = root.appendingPathComponent("Contents.json")
if !fm.fileExists(atPath: catalog.path) {
    try Data("{\n  \"info\" : {\n    \"author\" : \"xcode\",\n    \"version\" : 1\n  }\n}\n".utf8).write(to: catalog)
}

let start = Date()
let elongations = Array(stride(from: 0, to: 360, by: step))
let images = UnsafeMutableBufferPointer<CGImage?>.allocate(capacity: elongations.count)
images.initialize(repeating: nil)
DispatchQueue.concurrentPerform(iterations: elongations.count) { i in
    images[i] = renderer.render(elongation: Double(elongations[i]), size: size)
}
for (i, e) in elongations.enumerated() {
    let name = String(format: "moon-%03d", e)
    let set = root.appendingPathComponent("\(name).imageset")
    try fm.createDirectory(at: set, withIntermediateDirectories: true)
    writePNG(images[i]!, to: set.appendingPathComponent("\(name).png"))
    let json = """
    {
      "images" : [
        {
          "filename" : "\(name).png",
          "idiom" : "universal"
        }
      ],
      "info" : {
        "author" : "xcode",
        "version" : 1
      }
    }

    """
    try Data(json.utf8).write(to: set.appendingPathComponent("Contents.json"))
}
images.deallocate()
print("moonrender: \(elongations.count) frames, \(size) px, in \(String(format: "%.1f", Date().timeIntervalSince(start))) s")
