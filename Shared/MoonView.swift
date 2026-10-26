import SwiftUI

enum MoonGeometry {
    /// Horizontal scale of the terminator half-ellipse, 1 − 2k: 1 at new moon, 0 at quarter, −1 at full moon.
    static func terminatorScaleX(illumination: Double) -> Double {
        1 - 2 * min(max(illumination, 0), 1)
    }

    /// Lit limb on the right when waxing in the northern hemisphere; mirrored in the southern one.
    static func litOnRight(isWaxing: Bool, latitude: Double) -> Bool {
        latitude >= 0 ? isWaxing : !isWaxing
    }
}

/// The lit part of the disk: the lit limb's semicircle, closed by the terminator half-ellipse.
struct MoonLitShape: Shape {
    var illumination: Double
    var litOnRight: Bool

    func path(in rect: CGRect) -> Path {
        let r = min(rect.width, rect.height) / 2
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let s = MoonGeometry.terminatorScaleX(illumination: illumination)
        let side: Double = litOnRight ? 1 : -1
        let steps = 64
        var path = Path()
        // Limb from top to bottom, then terminator from bottom back to top (t from −90° to 90°).
        for i in 0...steps {
            let t = -Double.pi / 2 + Double.pi * Double(i) / Double(steps)
            let p = CGPoint(x: c.x + side * r * cos(t), y: c.y + r * sin(t))
            i == 0 ? path.move(to: p) : path.addLine(to: p)
        }
        for i in stride(from: steps, through: 0, by: -1) {
            let t = -Double.pi / 2 + Double.pi * Double(i) / Double(steps)
            path.addLine(to: CGPoint(x: c.x + side * s * r * cos(t), y: c.y + r * sin(t)))
        }
        path.closeSubpath()
        return path
    }
}

struct MoonView: View {
    let illumination: Double
    let isWaxing: Bool
    let latitude: Double
    /// Full-colour rendering uses a moonlit palette; accented/vibrant modes use the foreground style only.
    var fullColor = true

    var body: some View {
        ZStack {
            Circle().fill(fullColor ? AnyShapeStyle(Color(white: 0.16)) : AnyShapeStyle(.primary.opacity(0.18)))
            MoonLitShape(illumination: illumination,
                         litOnRight: MoonGeometry.litOnRight(isWaxing: isWaxing, latitude: latitude))
                .fill(fullColor ? AnyShapeStyle(Color(red: 0.96, green: 0.94, blue: 0.86)) : AnyShapeStyle(.primary))
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
