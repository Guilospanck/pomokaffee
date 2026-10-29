// Draws the 1280x640 GitHub social preview image.
// Usage: swift scripts/make-social.swift <icon.png> <out.png>
import AppKit

let w = 1280, h = 640
let icon = NSImage(contentsOfFile: CommandLine.arguments[1])!
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let bg = NSGradient(starting: NSColor(red: 0.98, green: 0.94, blue: 0.88, alpha: 1),
                    ending: NSColor(red: 0.95, green: 0.87, blue: 0.78, alpha: 1))!
bg.draw(in: NSRect(x: 0, y: 0, width: w, height: h), angle: -90)

let size: CGFloat = 360
icon.draw(in: NSRect(x: 130, y: (CGFloat(h) - size) / 2, width: size, height: size))

let ink = NSColor(red: 0.24, green: 0.13, blue: 0.10, alpha: 1)
let title = NSAttributedString(string: "Pomokaffee", attributes: [
    .font: NSFont.systemFont(ofSize: 96, weight: .bold), .foregroundColor: ink])
title.draw(at: NSPoint(x: 540, y: 330))
let lines = ["Menu bar pomodoro for macOS.", "Focus, rest, calls, keep awake."]
for (i, l) in lines.enumerated() {
    NSAttributedString(string: l, attributes: [
        .font: NSFont.systemFont(ofSize: 38, weight: .regular),
        .foregroundColor: ink.withAlphaComponent(0.75)]).draw(at: NSPoint(x: 544, y: 260 - CGFloat(i) * 52))
}
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
