// Draws the app icon (tomato-red squircle, cream cup with steam) into <dir>/Pomokaffee.iconset.
// Usage: swift scripts/make-icon.swift <dir>
import AppKit

func draw(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    let k = CGFloat(px) / 1024
    ctx.scaleBy(x: k, y: k)

    // Squircle with the macOS icon margin.
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let shape = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)
    ctx.saveGState()
    ctx.addPath(shape); ctx.clip()
    let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
        CGColor(red: 0.95, green: 0.42, blue: 0.30, alpha: 1), CGColor(red: 0.78, green: 0.22, blue: 0.17, alpha: 1)
    ] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    ctx.restoreGState()

    // Design is laid out on a 100-unit grid (tile 5...95); map to the 1024 canvas, y up.
    let u: CGFloat = 824 / 90
    // The cup artwork is centred on (53, 46) and enlarged by `zoom` to fill the tile.
    let zoom: CGFloat = 1.5
    func X(_ v: CGFloat) -> CGFloat { 100 + (50 + (v - 53) * zoom - 5) * u }
    func Y(_ v: CGFloat) -> CGFloat { 924 - (50 + (v - 46) * zoom - 5) * u }
    func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: X(x), y: Y(y)) }
    let cream = CGColor(red: 1, green: 0.953, blue: 0.894, alpha: 1)
    ctx.setLineCap(.round)

    // Cup.
    ctx.setFillColor(cream)
    let cup = CGMutablePath()
    cup.move(to: P(36, 43))
    cup.addLine(to: P(63, 43))
    cup.addLine(to: P(63, 52))
    cup.addArc(center: P(49.5, 52), radius: 13.5 * zoom * u, startAngle: 0, endAngle: .pi, clockwise: true)
    cup.closeSubpath()
    ctx.addPath(cup); ctx.fillPath()

    ctx.setStrokeColor(cream)
    ctx.setLineWidth(4.5 * zoom * u)
    ctx.move(to: P(63, 47))
    ctx.addLine(to: P(65.5, 47))
    ctx.addArc(center: P(65.5, 53), radius: 6 * zoom * u, startAngle: .pi / 2, endAngle: -.pi / 2, clockwise: true)
    ctx.addLine(to: P(62, 59))
    ctx.strokePath()

    // Steam.
    ctx.setLineWidth(3.5 * zoom * u)
    ctx.setStrokeColor(cream.copy(alpha: 0.85)!)
    for dx in [0.0, 11.0] as [CGFloat] {
        ctx.move(to: P(44 + dx, 37))
        ctx.addCurve(to: P(44 + dx, 26), control1: P(40 + dx, 33), control2: P(48 + dx, 31))
        ctx.strokePath()
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let dir = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent("Pomokaffee.iconset")
try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try draw(base).write(to: dir.appendingPathComponent("icon_\(base)x\(base).png"))
    try draw(base * 2).write(to: dir.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
