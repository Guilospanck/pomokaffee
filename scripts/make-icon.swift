// Draws the app icon (tomato-red squircle, white cup with steam) into <dir>/Pomokaffee.iconset.
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

    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.setLineCap(.round)

    let cup = CGMutablePath()
    cup.move(to: CGPoint(x: 290, y: 560))
    cup.addLine(to: CGPoint(x: 690, y: 560))
    cup.addLine(to: CGPoint(x: 690, y: 450))
    cup.addCurve(to: CGPoint(x: 490, y: 290), control1: CGPoint(x: 690, y: 360), control2: CGPoint(x: 610, y: 290))
    cup.addCurve(to: CGPoint(x: 290, y: 450), control1: CGPoint(x: 370, y: 290), control2: CGPoint(x: 290, y: 360))
    cup.closeSubpath()
    ctx.addPath(cup); ctx.fillPath()

    ctx.setLineWidth(46)
    ctx.addEllipse(in: CGRect(x: 640, y: 380, width: 130, height: 110))
    ctx.strokePath()

    ctx.setLineWidth(38)
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.85))
    for x in [400.0, 580.0] as [CGFloat] {
        ctx.move(to: CGPoint(x: x, y: 620))
        ctx.addCurve(to: CGPoint(x: x, y: 800), control1: CGPoint(x: x + 50, y: 670), control2: CGPoint(x: x - 50, y: 750))
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
