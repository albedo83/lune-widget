import CoreGraphics
import Foundation

/// Renders the Moon as seen from Earth (sub-Earth point at lat 0, lon 0, lunar north up, no libration),
/// textured with NASA's CGI Moon Kit colour and elevation maps and lit for a given elongation.
public struct Renderer: Sendable {
    /// Lunar-Lambert weight: 1 = pure Lommel-Seeliger (flat full moon), 0 = pure Lambert.
    public var lunarLambertL = 0.8
    /// Relief exaggeration applied to the elevation map, for both the bump normals and the cast shadows.
    public var reliefExaggeration = 3.0
    /// Earthshine brightness on the night side at new moon, as a fraction of full-moon brightness.
    public var maxEarthshine = 0.006
    /// Linear brightness of the average full-moon albedo before tone mapping.
    public var exposure = 0.45
    /// Power applied to the linear albedo (> 1 deepens the maria against the highlands).
    public var albedoContrast = 1.5
    /// Fraction of the colour map's saturation kept (the LROC mosaic is colour-enhanced).
    public var saturation = 0.6
    /// Supersampling factor per axis.
    public var supersample = 2

    static let moonRadius = 1_737_400.0
    static let elevationReference = 1_727_400.0

    private let albedo: [Grid]  // 3 channels, linear; mip levels, full resolution first
    private let height: Grid  // 1 channel, metres above `moonRadius`
    private let meanAlbedo: Double

    public init(colorMap: CGImage, heightMap: CGImage) {
        var levels = [Grid.linearRGB(colorMap)]
        while let last = levels.last, last.width >= 16, last.height >= 16 { levels.append(last.halved()) }
        albedo = levels
        height = Grid.elevation(heightMap)
        let top = levels[0]
        var sum = 0.0
        for i in stride(from: 0, to: top.values.count, by: 3) {
            sum += 0.2126 * top.values[i] + 0.7152 * top.values[i + 1] + 0.0722 * top.values[i + 2]
        }
        meanAlbedo = sum / Double(top.values.count / 3)
    }

    /// Frame for `elongation` degrees (0 = new, 90 = first quarter lit on the right, 180 = full), `size` × `size`
    /// pixels, transparent outside a disk of diameter `size − 2`.
    public func render(elongation: Double, size: Int) -> CGImage {
        let e = elongation * .pi / 180
        let sun = Vec(sin(e), 0, -cos(e))
        let illumination = (1 - cos(e)) / 2
        let earthshine = maxEarthshine * (1 - illumination)
        let radius = Double(size - 2) / 2
        let centre = Double(size) / 2
        let ss = max(supersample, 1)
        let albedoScale = 1 / pow(meanAlbedo, albedoContrast)

        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        for py in 0..<size {
            for px in 0..<size {
                let dx = Double(px) + 0.5 - centre, dy = Double(py) + 0.5 - centre
                let coverage = min(max(radius - (dx * dx + dy * dy).squareRoot() + 0.5, 0), 1)
                if coverage == 0 { continue }
                var rgb = (0.0, 0.0, 0.0)
                for sy in 0..<ss {
                    for sx in 0..<ss {
                        var x = (Double(px) + (Double(sx) + 0.5) / Double(ss) - centre) / radius
                        var y = -(Double(py) + (Double(sy) + 0.5) / Double(ss) - centre) / radius
                        let r2 = x * x + y * y
                        if r2 > 0.9999 { let k = (0.9999 / r2).squareRoot(); x *= k; y *= k }
                        let c = shade(x: x, y: y, sun: sun, earthshine: earthshine, albedoScale: albedoScale,
                                      sampleSize: 1 / (radius * Double(ss)))
                        rgb.0 += c.0; rgb.1 += c.1; rgb.2 += c.2
                    }
                }
                let n = Double(ss * ss)
                let i = (py * size + px) * 4
                pixels[i] = Self.encode(rgb.0 / n, alpha: coverage)
                pixels[i + 1] = Self.encode(rgb.1 / n, alpha: coverage)
                pixels[i + 2] = Self.encode(rgb.2 / n, alpha: coverage)
                pixels[i + 3] = UInt8((coverage * 255).rounded())
            }
        }
        let provider = CGDataProvider(data: Data(pixels) as CFData)!
        return CGImage(width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: size * 4,
                       space: CGColorSpace(name: CGColorSpace.sRGB)!,
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
    }

    /// Linear RGB radiance of the disk point (x right, y up, both in −1…1).
    /// `sampleSize` is the sample spacing in disk radii, used to pick the colour map's mip level.
    private func shade(x: Double, y: Double, sun: Vec, earthshine: Double, albedoScale: Double,
                       sampleSize: Double) -> (Double, Double, Double) {
        let z = max(1 - x * x - y * y, 0).squareRoot()
        let normal = Vec(x, y, z)
        let lat = asin(min(max(y, -1), 1))
        let lon = atan2(x, z)
        let (u, v) = Self.texture(lat: lat, lon: lon)
        // Surface footprint of one sample, stretched by foreshortening towards the limb.
        let footprint = sampleSize / max(z, 0.02)
        let level = max(log2(footprint * Double(albedo[0].width) / (2 * .pi)), 0)
        let l0 = min(Int(level), albedo.count - 1), l1 = min(l0 + 1, albedo.count - 1)
        let t = min(level - Double(l0), 1)
        let a0 = albedo[l0].sample3(u, v), a1 = albedo[l1].sample3(u, v)
        let a = (a0.0 + (a1.0 - a0.0) * t, a0.1 + (a1.1 - a0.1) * t, a0.2 + (a1.2 - a0.2) * t)
        let grey = 0.2126 * a.0 + 0.7152 * a.1 + 0.0722 * a.2
        let albedoRGB = (pow(grey + saturation * (a.0 - grey), albedoContrast) * albedoScale,
                         pow(grey + saturation * (a.1 - grey), albedoContrast) * albedoScale,
                         pow(grey + saturation * (a.2 - grey), albedoContrast) * albedoScale)

        // Local frame on the sphere, as seen from Earth: east and north unit tangents.
        let east = Vec(cos(lon), 0, -sin(lon))
        let north = Vec(-sin(lat) * sin(lon), cos(lat), -sin(lat) * cos(lon))

        var direct = 0.0
        let mu0Sphere = normal.dot(sun)
        if mu0Sphere > -0.15 {
            // Elevation gradient (dimensionless slopes) from central differences on the elevation map.
            let du = 1 / Double(height.width), dv = 1 / Double(height.height)
            let metresPerU = 2 * .pi * Self.moonRadius * max(cos(lat), 0.02)
            let metresPerV = .pi * Self.moonRadius
            let gEast = (height.sample(u + du, v) - height.sample(u - du, v)) / (2 * du * metresPerU)
            let gNorth = -(height.sample(u, v + dv) - height.sample(u, v - dv)) / (2 * dv * metresPerV)
            // Fade the relief out towards the limb, where the map is foreshortened below the pixel size.
            let limbFade = min(max((z - 0.05) / 0.2, 0), 1)
            let bumped = (normal - (east * gEast + north * gNorth) * (reliefExaggeration * limbFade)).normalized
            let mu0 = bumped.dot(sun)
            let mu = bumped.z
            // Facets tilted away from the viewer are hidden by their own slope.
            if mu0 > 0, mu > 0 {
                let ll = lunarLambertL * 2 * mu0 / (mu0 + mu) + (1 - lunarLambertL) * mu0
                // On the day side, shadows near the limb are foreshortened below the pixel size (and hidden at
                // small phase angles); beyond the terminator only peaks that really see the sun stay lit.
                let shadow = castShadow(lat: lat, lon: lon, u: u, v: v, sun: sun, east: east, north: north,
                                        normal: normal)
                direct = ll * (1 - (1 - shadow) * (mu0Sphere > 0 ? limbFade : 1))
            }
        }
        // Earthshine comes from the viewer's direction: nearly flat across the disk.
        let light = exposure * (direct + earthshine)
        return (albedoRGB.0 * light, albedoRGB.1 * light, albedoRGB.2 * light)
    }

    /// 1 when the sun is visible above the local terrain horizon, 0 in a cast shadow (soft-edged).
    private func castShadow(lat: Double, lon: Double, u: Double, v: Double, sun: Vec, east: Vec, north: Vec,
                            normal: Vec) -> Double {
        let sinElevation = normal.dot(sun)
        guard sinElevation < 0.2 else { return 1 }
        let tanElevation = sinElevation / max((1 - sinElevation * sinElevation).squareRoot(), 1e-6)
        // Sun azimuth in the local tangent plane.
        let se = sun.dot(east), sn = sun.dot(north)
        let horizontal = (se * se + sn * sn).squareRoot()
        guard horizontal > 1e-9 else { return 1 }
        let (de, dn) = (se / horizontal, sn / horizontal)
        let h0 = height.sample(u, v) * reliefExaggeration
        let step = 4_000.0
        var visibility = 1.0
        var d = step
        while d <= 160_000 {
            let lat1 = lat + dn * d / Self.moonRadius
            let lon1 = lon + de * d / (Self.moonRadius * max(cos(lat), 0.02))
            let (u1, v1) = Self.texture(lat: lat1, lon: lon1)
            // Height of the sun ray above the reference sphere, including the sphere's curvature drop.
            let ray = h0 + d * tanElevation + d * d / (2 * Self.moonRadius)
            let terrain = height.sample(u1, v1) * reliefExaggeration
            visibility = min(visibility, max(0, min(1, 0.5 + (ray - terrain) / 600)))
            if visibility == 0 { break }
            d += step
        }
        return visibility
    }

    static func texture(lat: Double, lon: Double) -> (Double, Double) {
        var u = (lon + .pi) / (2 * .pi)
        u -= u.rounded(.down)
        return (u, 0.5 - lat / .pi)
    }

    /// sRGB-encoded, premultiplied channel value.
    static func encode(_ linear: Double, alpha: Double) -> UInt8 {
        // Soft shoulder so bright rays do not clip hard.
        let l = linear < 0.8 ? linear : 0.8 + 0.2 * (1 - exp(-(linear - 0.8) / 0.2))
        let c = max(min(l, 1), 0)
        let s = c <= 0.0031308 ? 12.92 * c : 1.055 * pow(c, 1 / 2.4) - 0.055
        return UInt8((s * alpha * 255).rounded())
    }
}

struct Vec {
    var x, y, z: Double
    init(_ x: Double, _ y: Double, _ z: Double) { self.x = x; self.y = y; self.z = z }
    func dot(_ o: Vec) -> Double { x * o.x + y * o.y + z * o.z }
    var normalized: Vec { let l = dot(self).squareRoot(); return Vec(x / l, y / l, z / l) }
    static func + (a: Vec, b: Vec) -> Vec { Vec(a.x + b.x, a.y + b.y, a.z + b.z) }
    static func - (a: Vec, b: Vec) -> Vec { Vec(a.x - b.x, a.y - b.y, a.z - b.z) }
    static func * (a: Vec, k: Double) -> Vec { Vec(a.x * k, a.y * k, a.z * k) }
}

/// Equirectangular map with bilinear sampling; u wraps (longitude), v clamps (latitude).
struct Grid: Sendable {
    let width: Int, height: Int, channels: Int
    let values: [Double]

    func sample(_ u: Double, _ v: Double) -> Double { sample(u, v, channel: 0) }

    func sample3(_ u: Double, _ v: Double) -> (Double, Double, Double) {
        (sample(u, v, channel: 0), sample(u, v, channel: 1), sample(u, v, channel: 2))
    }

    private func sample(_ u: Double, _ v: Double, channel: Int) -> Double {
        let fx = u * Double(width) - 0.5, fy = min(max(v * Double(height) - 0.5, 0), Double(height - 1))
        let x0 = Int(fx.rounded(.down)), y0 = Int(fy.rounded(.down))
        let tx = fx - Double(x0), ty = fy - Double(y0)
        let xa = ((x0 % width) + width) % width, xb = (xa + 1) % width
        let ya = y0, yb = min(y0 + 1, height - 1)
        func at(_ x: Int, _ y: Int) -> Double { values[(y * width + x) * channels + channel] }
        let top = at(xa, ya) * (1 - tx) + at(xb, ya) * tx
        let bottom = at(xa, yb) * (1 - tx) + at(xb, yb) * tx
        return top * (1 - ty) + bottom * ty
    }

    /// Next mip level: 2 × 2 box filter.
    func halved() -> Grid {
        let w = width / 2, h = height / 2
        var out = [Double](repeating: 0, count: w * h * channels)
        for y in 0..<h {
            for x in 0..<w {
                for c in 0..<channels {
                    func at(_ xx: Int, _ yy: Int) -> Double { values[(yy * width + xx) * channels + c] }
                    out[(y * w + x) * channels + c] =
                        (at(2 * x, 2 * y) + at(2 * x + 1, 2 * y) + at(2 * x, 2 * y + 1) + at(2 * x + 1, 2 * y + 1)) / 4
                }
            }
        }
        return Grid(width: w, height: h, channels: channels, values: out)
    }

    /// Colour map drawn into sRGB RGBA8, decoded to linear RGB.
    static func linearRGB(_ image: CGImage) -> Grid {
        let w = image.width, h = image.height
        var buf = [UInt8](repeating: 0, count: w * h * 4)
        let ctx = CGContext(data: &buf, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        let table = (0..<256).map { i -> Double in
            let s = Double(i) / 255
            return s <= 0.04045 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4)
        }
        var values = [Double](repeating: 0, count: w * h * 3)
        for p in 0..<(w * h) {
            for c in 0..<3 { values[p * 3 + c] = table[Int(buf[p * 4 + c])] }
        }
        return Grid(width: w, height: h, channels: 3, values: values)
    }

    /// 16-bit elevation map (half-metres above 1 727 400 m) read raw, without colour management.
    static func elevation(_ image: CGImage) -> Grid {
        precondition(image.bitsPerComponent == 16 && image.bitsPerPixel == 16, "expected 16-bit grey elevation")
        let w = image.width, h = image.height
        let data = image.dataProvider!.data! as Data
        let bigEndian = image.bitmapInfo.contains(.byteOrder16Big)
        var values = [Double](repeating: 0, count: w * h)
        data.withUnsafeBytes { raw in
            for y in 0..<h {
                for x in 0..<w {
                    let o = y * image.bytesPerRow + x * 2
                    let b0 = UInt16(raw[o]), b1 = UInt16(raw[o + 1])
                    let half = bigEndian ? (b0 << 8 | b1) : (b1 << 8 | b0)
                    values[y * w + x] = Renderer.elevationReference + Double(half) / 2 - Renderer.moonRadius
                }
            }
        }
        return Grid(width: w, height: h, channels: 1, values: values)
    }
}
