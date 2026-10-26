import CoreGraphics
import Foundation
import ImageIO
import MoonRenderCore
import UniformTypeIdentifiers

// moonrender <out-dir> [--size 256] [--step 5]
// Writes one imageset per elongation step: <out-dir>/moon-EEE.imageset/{moon-EEE.png, Contents.json}.

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("moonrender: \(message)\n".utf8))
    exit(1)
}

var args = Array(CommandLine.arguments.dropFirst())
var size = 256, step = 5
var outDir: String?
while !args.isEmpty {
    let a = args.removeFirst()
    switch a {
    case "--size": guard let v = Int(args.isEmpty ? "" : args.removeFirst()) else { fail("--size needs an integer") }; size = v
    case "--step": guard let v = Int(args.isEmpty ? "" : args.removeFirst()) else { fail("--step needs an integer") }; step = v
    default: if outDir == nil { outDir = a } else { fail("unexpected argument \(a)") }
    }
}
guard let outDir, size > 8, step > 0, 360 % step == 0 else {
    fail("usage: moonrender <out-dir> [--size 256] [--step 5]  (step must divide 360)")
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
    let png = set.appendingPathComponent("\(name).png")
    guard let dest = CGImageDestinationCreateWithURL(png as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { fail("cannot write \(png.path)") }
    CGImageDestinationAddImage(dest, images[i]!, nil)
    guard CGImageDestinationFinalize(dest) else { fail("cannot write \(png.path)") }
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
