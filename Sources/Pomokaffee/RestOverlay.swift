import SwiftUI
import AppKit

private final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Full-screen blocker shown during rest, on every display.
final class RestOverlay {
    private var windows: [NSWindow] = []
    private var observer: NSObjectProtocol?

    func show(engine: Engine, onUnlock: @escaping () -> Void) {
        hide()
        let primary = NSScreen.main
        for screen in NSScreen.screens {
            let w = OverlayWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            w.setFrame(screen.frame, display: true)
            w.level = .screenSaver
            w.isReleasedWhenClosed = false
            w.backgroundColor = .black
            w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            w.contentView = NSHostingView(rootView: RestView(engine: engine, showsControls: screen == primary, onUnlock: onUnlock))
            w.makeKeyAndOrderFront(nil)
            windows.append(w)
        }
        NSApp.presentationOptions = [.hideDock, .hideMenuBar, .disableProcessSwitching, .disableHideApplication]
        NSApp.activate(ignoringOtherApps: true)
        observer = NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification,
                                                          object: nil, queue: .main) { [weak self] _ in
            guard let self, !self.windows.isEmpty else { return }
            NSApp.activate(ignoringOtherApps: true)
            self.windows.first?.makeKeyAndOrderFront(nil)
        }
    }

    func hide() {
        if let o = observer { NotificationCenter.default.removeObserver(o); observer = nil }
        guard !windows.isEmpty else { return }
        NSApp.presentationOptions = []
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
    }
}

struct RestView: View {
    @ObservedObject var engine: Engine
    let showsControls: Bool
    let onUnlock: () -> Void

    private var progress: Double {
        engine.total > 0 ? 1 - Double(engine.remaining) / Double(engine.total) : 0
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.07, green: 0.07, blue: 0.09), Color(red: 0.13, green: 0.10, blue: 0.12)],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 28) {
                if showsControls {
                    AppleEatenView(progress: progress).frame(width: 240, height: 240)
                }
                Text(timeString(engine.remaining))
                    .font(.system(size: 76, weight: .ultraLight, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.92))
                Text("Rest. Look far away. Stand up. Breathe.")
                    .font(.system(size: 17, weight: .light, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                if showsControls { UnlockBox(onUnlock: onUnlock).padding(.top, 36) }
            }
        }
    }
}

private struct UnlockBox: View {
    static let phrase = "I solemnly swear that my eyes, my back and my wrists do not need any rest at all, and I choose to ignore them anyway."

    let onUnlock: () -> Void
    @State private var open = false
    @State private var text = ""

    private var isPrefix: Bool { Self.phrase.hasPrefix(text) }

    var body: some View {
        VStack(spacing: 10) {
            if !open {
                Button("Skip rest…") { open = true }
                    .buttonStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.3))
            } else {
                Text(Self.phrase)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 560)
                PhraseField(text: $text)
                    .frame(width: 560, height: 24)
                Text(isPrefix ? "\(text.count) / \(Self.phrase.count)" : "Typo. Fix it.")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(isPrefix ? .white.opacity(0.35) : Color.red.opacity(0.8))
            }
        }
        .onChange(of: text) { _, new in
            if new == Self.phrase { onUnlock() }
        }
    }
}

/// Text field that rejects pasting: any single edit adding more than one character is reverted.
private struct PhraseField: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSTextField {
        let f = NSTextField()
        f.delegate = context.coordinator
        f.placeholderString = "Type the phrase above to skip"
        f.isBezeled = true
        f.bezelStyle = .roundedBezel
        f.focusRingType = .none
        DispatchQueue.main.async { f.window?.makeFirstResponder(f) }
        return f
    }

    func updateNSView(_ f: NSTextField, context: Context) {
        if f.stringValue != text { f.stringValue = text }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: PhraseField
        init(_ p: PhraseField) { parent = p }

        func controlTextDidChange(_ n: Notification) {
            guard let f = n.object as? NSTextField else { return }
            if f.stringValue.count - parent.text.count > 1 { f.stringValue = parent.text; return }
            parent.text = f.stringValue
        }
    }
}

func timeString(_ seconds: Int) -> String {
    let s = max(0, seconds)
    return String(format: "%d:%02d", s / 60, s % 60)
}
