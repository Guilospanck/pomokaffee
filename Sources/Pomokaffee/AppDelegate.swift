import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = Settings.shared
    private let engine = Engine()
    private let detector = MeetingDetector()
    private let caffeine = Caffeine()
    private let integrations = Integrations()
    private let overlay = RestOverlay()
    private let warning = WarningPanel()

    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var lastPhase: Engine.Phase?
    private var steamTimer: Timer?
    private var sigterm: DispatchSourceSignal?
    private var steamPhase: CGFloat = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMainMenu()
        // `pkill` (just install/uninstall) sends SIGTERM; turn it into a normal quit so cleanup runs.
        signal(SIGTERM, SIG_IGN)
        let src = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        src.setEventHandler { NSApp.terminate(nil) }
        src.resume()
        sigterm = src
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        settings.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.applyKeepAlive(); self?.refreshIcon() }
        }.store(in: &bag)

        engine.onPauseChange = { [weak self] paused in
            guard let self else { return }
            if paused { integrations.focusOff() } else { integrations.focusOn(minutes: engine.remaining / 60 + 20) }
        }
        // Flipping the Shortcuts switch applies at once, if Focus should currently be on.
        settings.$shortcutsEnabled.dropFirst().removeDuplicates().sink { [weak self] on in
            guard let self, engine.phase != .rest, !engine.paused else { return }
            integrations.setShortcutFocus(on: on)
        }.store(in: &bag)
        detector.start()
        engine.isInMeeting = { [weak self] in self?.detector.isInMeeting ?? false }
        engine.onChange = { [weak self] in self?.engineChanged() }
        engine.onFocusStart = { [weak self] in
            guard let self else { return }
            integrations.focusOn(minutes: engine.remaining / 60 + 20)
        }
        applyKeepAlive()
        engine.start()

        let t = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in self?.animateSteam() }
        RunLoop.main.add(t, forMode: .common)
        steamTimer = t
    }

    func applicationWillTerminate(_ notification: Notification) {
        caffeine.stop()
        // Focus is already off during a rest or a pause.
        integrations.shutdown(focusIsOn: lastPhase != .rest && !engine.paused)
    }

    // MARK: Engine -> side effects

    private var bag = Set<AnyCancellable>()

    private func engineChanged() {
        let new = engine.phase, old = lastPhase
        lastPhase = new
        refreshTitle()
        guard new != old else { return }

        if new == .rest {
            integrations.focusOff()
            integrations.runRestScripts()
            overlay.show(engine: engine) { [weak self] in self?.engine.startFocus() }
        }
        if old == .rest && new != .rest { overlay.hide() }
        if new == .warning {
            warning.show(engine: engine,
                         onPostpone: { [weak self] in self?.engine.postpone() },
                         onRestNow: { [weak self] in self?.engine.startRest() })
        }
        if old == .warning && new != .warning { warning.hide() }
    }

    private var keepAliveOn: Bool { settings.keepAwake && settings.activeKeepAlive != nil }

    private func applyKeepAlive() {
        caffeine.set(settings.keepAwake ? settings.activeKeepAlive : nil)
    }

    // MARK: Status item

    private func refreshTitle() {
        guard let button = statusItem?.button else { return }
        let text: String
        switch engine.phase {
        case .waiting: text = " meeting"
        default: text = engine.paused ? " paused" : " " + timeString(engine.remaining)
        }
        button.attributedTitle = NSAttributedString(string: text, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        ])
    }

    private func refreshIcon() {
        // Calm in focus: slow, small steam. Livelier when rest is near.
        let (speed, amp): (CGFloat, CGFloat) = {
            switch engine.phase {
            case .warning, .waiting: return (0.9, 1.1)
            case .focus: return (0.12, 0.5)
            case .rest: return (0.3, 0.8)
            }
        }()
        steamPhase += speed
        statusItem?.button?.image = StatusIcon.image(phase: steamPhase, amplitude: amp,
                                                     steamAlpha: keepAliveOn ? 1 : 0.4)
    }

    private func animateSteam() {
        refreshIcon()
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let status: String
        switch engine.phase {
        case .focus: status = "Focus · \(timeString(engine.remaining)) left"
        case .warning: status = "Rest soon · \(timeString(engine.remaining))"
        case .waiting: status = "Waiting for your meeting to end"
        case .rest: status = "Resting · \(timeString(engine.remaining)) left"
        }
        menu.addItem(withTitle: status, action: nil, keyEquivalent: "").isEnabled = false
        menu.addItem(.separator())
        if engine.phase != .rest {
            add(menu, engine.paused ? "Resume" : "Pause", #selector(togglePause), symbol: engine.paused ? "play.fill" : "pause.fill")
            add(menu, "Rest now", #selector(restNow), symbol: "cup.and.saucer.fill")
            add(menu, "Restart focus", #selector(restartFocus), symbol: "arrow.counterclockwise")
            menu.addItem(.separator())
        }
        let awake = menu.addItem(withTitle: "Keep awake", action: #selector(toggleKeepAwake), keyEquivalent: "")
        awake.target = self
        awake.state = keepAliveOn ? .on : .off
        awake.isEnabled = settings.activeKeepAlive != nil
        add(menu, "I'm in a meeting", #selector(toggleManualMeeting), checked: detector.manual)
        if detector.detected {
            menu.addItem(withTitle: "Call detected (mic/camera in use)", action: nil, keyEquivalent: "").isEnabled = false
        }
        menu.addItem(.separator())
        add(menu, "Settings…", #selector(openSettings), key: ",", symbol: "gearshape")
        add(menu, "Quit Pomokaffee", #selector(NSApplication.terminate(_:)), key: "q", target: NSApp)
    }

    private func add(_ menu: NSMenu, _ title: String, _ action: Selector, key: String = "",
                     checked: Bool = false, target: AnyObject? = nil, symbol: String? = nil) {
        let item = menu.addItem(withTitle: title, action: action, keyEquivalent: key)
        if let symbol { item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) }
        item.target = target ?? self
        item.state = checked ? .on : .off
    }

    @objc private func togglePause() { engine.togglePause() }
    @objc private func restNow() { engine.startRest() }
    @objc private func restartFocus() { engine.startFocus() }
    @objc private func toggleKeepAwake() { settings.keepAwake.toggle() }
    @objc private func toggleManualMeeting() { detector.manual.toggle() }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(s: settings)))
            w.title = "Pomokaffee"
            w.styleMask = [.titled, .closable, .fullSizeContentView]
            w.titlebarAppearsTransparent = true
            w.isReleasedWhenClosed = false
            w.center()
            settingsWindow = w
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
        // AppKit hands focus to the first text field; drop it so no field starts selected.
        // SwiftUI assigns it a moment after the window shows, so repeat once or twice.
        for delay in [0.0, 0.1, 0.3] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.settingsWindow?.makeFirstResponder(nil) }
        }
    }

    /// Accessory apps have no menu bar, so Cmd-C/V need an Edit menu to work in text fields.
    private func buildMainMenu() {
        let main = NSMenu()
        let editItem = NSMenuItem()
        main.addItem(editItem)
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        NSApp.mainMenu = main
    }
}
