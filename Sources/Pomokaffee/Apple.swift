import SwiftUI
import AppKit

/// Shared apple silhouette. Unit coordinates are y-up; `flipped` maps to y-down (SwiftUI).
func applePath(in r: CGRect, flipped: Bool) -> CGPath {
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: r.minX + x * r.width, y: flipped ? r.maxY - y * r.height : r.minY + y * r.height)
    }
    let path = CGMutablePath()
    path.move(to: p(0.5, 0.74))
    path.addCurve(to: p(0.14, 0.48), control1: p(0.38, 0.86), control2: p(0.14, 0.72))
    path.addCurve(to: p(0.34, 0.07), control1: p(0.14, 0.26), control2: p(0.22, 0.07))
    path.addCurve(to: p(0.5, 0.13), control1: p(0.41, 0.07), control2: p(0.46, 0.13))
    path.addCurve(to: p(0.66, 0.07), control1: p(0.54, 0.13), control2: p(0.59, 0.07))
    path.addCurve(to: p(0.86, 0.48), control1: p(0.78, 0.07), control2: p(0.86, 0.26))
    path.addCurve(to: p(0.5, 0.74), control1: p(0.86, 0.72), control2: p(0.62, 0.86))
    path.closeSubpath()
    return path
}

struct AppleShape: Shape {
    func path(in rect: CGRect) -> Path { Path(applePath(in: rect, flipped: true)) }
}

/// Menu bar icon: a cup with steam. Template image.
enum StatusIcon {
    static func image(phase: CGFloat, amplitude: CGFloat, steamAlpha: CGFloat) -> NSImage {
        let img = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.setFillColor(NSColor.black.cgColor)
            ctx.setStrokeColor(NSColor.black.cgColor)
            ctx.setLineCap(.round)

            // Cup body: flat rim, round bottom.
            let body = CGMutablePath()
            body.move(to: CGPoint(x: 2.5, y: 9.5))
            body.addLine(to: CGPoint(x: 12.5, y: 9.5))
            body.addLine(to: CGPoint(x: 12.5, y: 6))
            body.addCurve(to: CGPoint(x: 7.5, y: 1.5), control1: CGPoint(x: 12.5, y: 3.5), control2: CGPoint(x: 10.5, y: 1.5))
            body.addCurve(to: CGPoint(x: 2.5, y: 6), control1: CGPoint(x: 4.5, y: 1.5), control2: CGPoint(x: 2.5, y: 3.5))
            body.closeSubpath()
            ctx.addPath(body)
            ctx.fillPath()

            // Handle.
            ctx.setLineWidth(1.5)
            ctx.addEllipse(in: CGRect(x: 11, y: 4.2, width: 4.6, height: 3.8))
            ctx.strokePath()

            // Steam.
            ctx.setStrokeColor(NSColor.black.withAlphaComponent(steamAlpha).cgColor)
            ctx.setLineWidth(1.3)
            for baseX in [5.0, 10.0] as [CGFloat] {
                var t: CGFloat = 0
                while t <= 1.001 {
                    let pt = CGPoint(x: baseX + sin(t * 2 * .pi + phase + baseX) * amplitude * 0.8, y: 11.3 + t * 5)
                    t == 0 ? ctx.move(to: pt) : ctx.addLine(to: pt)
                    t += 0.1
                }
                ctx.strokePath()
            }
            return true
        }
        img.isTemplate = true
        return img
    }
}
