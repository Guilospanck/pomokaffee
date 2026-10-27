import SwiftUI

/// An apple that gets eaten as `progress` goes 0 -> 1, bite by bite.
struct AppleEatenView: View {
    let progress: Double

    private struct Bite { let x, y, r, start: Double }
    private static let bites: [Bite] = [
        .init(x: 0.92, y: 0.42, r: 0.17, start: 0.00),
        .init(x: 0.88, y: 0.62, r: 0.16, start: 0.10),
        .init(x: 0.84, y: 0.80, r: 0.17, start: 0.22),
        .init(x: 0.70, y: 0.92, r: 0.18, start: 0.34),
        .init(x: 0.14, y: 0.45, r: 0.20, start: 0.46),
        .init(x: 0.12, y: 0.70, r: 0.20, start: 0.56),
        .init(x: 0.28, y: 0.90, r: 0.20, start: 0.66),
        .init(x: 0.64, y: 0.30, r: 0.20, start: 0.76),
        .init(x: 0.34, y: 0.30, r: 0.20, start: 0.84),
    ]
    private static let span = 0.14

    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x * w, y: y * h) }
            ctx.drawLayer { layer in
                let apple = AppleShape().path(in: CGRect(origin: .zero, size: size))
                layer.fill(apple, with: .linearGradient(
                    Gradient(colors: [Color(red: 0.95, green: 0.42, blue: 0.38), Color(red: 0.78, green: 0.20, blue: 0.26)]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
                var stem = Path()
                stem.move(to: pt(0.5, 0.28))
                stem.addQuadCurve(to: pt(0.55, 0.08), control: pt(0.49, 0.15))
                layer.stroke(stem, with: .color(Color(red: 0.42, green: 0.28, blue: 0.2)),
                             style: StrokeStyle(lineWidth: w * 0.028, lineCap: .round))
                var leaf = Path()
                leaf.move(to: pt(0.56, 0.14))
                leaf.addQuadCurve(to: pt(0.78, 0.06), control: pt(0.63, 0.03))
                leaf.addQuadCurve(to: pt(0.56, 0.14), control: pt(0.72, 0.17))
                layer.fill(leaf, with: .color(Color(red: 0.45, green: 0.68, blue: 0.4)))

                layer.blendMode = .destinationOut
                for b in Self.bites {
                    let t = min(1, max(0, (progress - b.start) / Self.span))
                    guard t > 0 else { continue }
                    let r = b.r * t * w
                    layer.fill(Path(ellipseIn: CGRect(x: b.x * w - r, y: b.y * h - r, width: 2 * r, height: 2 * r)),
                               with: .color(.black))
                }
            }
        }
        .animation(.easeInOut(duration: 0.9), value: progress)
    }
}
