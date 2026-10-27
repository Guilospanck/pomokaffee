import SwiftUI
import AppKit

/// Small floating card, top-right, shown for the last minute before rest.
final class WarningPanel {
    private var panel: NSPanel?

    func show(engine: Engine, onPostpone: @escaping () -> Void, onRestNow: @escaping () -> Void) {
        hide()
        let host = NSHostingView(rootView: WarningView(engine: engine, onPostpone: onPostpone, onRestNow: onRestNow))
        let size = NSSize(width: 300, height: 150)
        let p = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.contentView = host
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.isReleasedWhenClosed = false
        if let f = NSScreen.main?.visibleFrame {
            p.setFrameOrigin(NSPoint(x: f.maxX - size.width - 16, y: f.maxY - size.height - 12))
        }
        p.orderFrontRegardless()
        panel = p
        NSSound(named: "Glass")?.play()
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
    }
}

private struct WarningView: View {
    @ObservedObject var engine: Engine
    let onPostpone: () -> Void
    let onRestNow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Rest in \(timeString(engine.remaining))")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .monospacedDigit()
                Spacer()
                Text("🍎")
            }
            Text("Wrap up. The screen will lock for \(Settings.shared.restMinutes) min.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            HStack {
                if let m = engine.postponeMinutes {
                    Button("+\(m) min") { onPostpone() }
                    Text("\(Engine.postponeSteps.count - engine.postponesUsed) left")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                } else {
                    Text("No postpones left").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Rest now") { onRestNow() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 300, height: 150, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
