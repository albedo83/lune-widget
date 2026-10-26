import CoreGraphics
import Foundation
import ImageIO
import XCTest
@testable import MoonRenderCore

final class RendererTests: XCTestCase {
    private static let renderer: Renderer = {
        let nasa = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("nasa")
        func load(_ name: String) -> CGImage {
            let src = CGImageSourceCreateWithURL(nasa.appendingPathComponent(name) as CFURL, nil)!
            return CGImageSourceCreateImageAtIndex(src, 0, nil)!
        }
        return Renderer(colorMap: load("lroc_color_2k.jpg"), heightMap: load("ldem_4_uint.tif"))
    }()

    /// Straight (un-premultiplied) RGBA pixels, row 0 at the top.
    private struct Pixels {
        let size: Int
        let data: [UInt8]
        init(_ image: CGImage) {
            size = image.width
            var buf = [UInt8](repeating: 0, count: size * size * 4)
            let ctx = CGContext(data: &buf, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
            data = buf
        }
        func alpha(_ x: Int, _ y: Int) -> Double { Double(data[(y * size + x) * 4 + 3]) / 255 }
        /// Luminance of the premultiplied colour (transparent pixels count as black).
        func luminance(_ x: Int, _ y: Int) -> Double {
            let i = (y * size + x) * 4
            return (0.2126 * Double(data[i]) + 0.7152 * Double(data[i + 1]) + 0.0722 * Double(data[i + 2])) / 255
        }
        func meanLuminance(_ xs: Range<Int>) -> Double {
            var sum = 0.0, n = 0.0
            for y in 0..<size { for x in xs where alpha(x, y) > 0.5 { sum += luminance(x, y); n += 1 } }
            return n > 0 ? sum / n : 0
        }
    }

    private func render(_ elongation: Double) -> Pixels {
        let image = Self.renderer.render(elongation: elongation, size: 64)
        XCTAssertEqual(image.width, 64)
        XCTAssertEqual(image.height, 64)
        return Pixels(image)
    }

    func testFullMoonCentreIsBright() {
        let p = render(180)
        XCTAssertGreaterThan(p.luminance(32, 32), 0.5)
        XCTAssertEqual(p.alpha(0, 0), 0)
    }

    func testNewMoonIsDark() {
        let p = render(0)
        XCTAssertEqual(p.alpha(32, 32), 1, "disk must be opaque")
        XCTAssertLessThan(p.meanLuminance(0..<64), 0.05)
    }

    func testFirstQuarterLitOnRight() {
        let p = render(90)
        XCTAssertGreaterThan(p.meanLuminance(32..<64), 5 * p.meanLuminance(0..<32))
    }

    func testLastQuarterLitOnLeft() {
        let p = render(270)
        XCTAssertGreaterThan(p.meanLuminance(0..<32), 5 * p.meanLuminance(32..<64))
    }
}
