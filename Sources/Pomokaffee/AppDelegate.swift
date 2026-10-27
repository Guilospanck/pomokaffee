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
    private var steamPhase: CGFloat = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMainMenu()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        settings.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.caffeine.set(self?.settings.keepAwake ?? false); self?.refreshIcon() }
        }.store(in: &bag)

        detector.start()
        engine.isInMeeting = { [weak self] in self?.detector.isInMeeting ?? false }
        engine.onChange = { [weak self] in self?.engineChanged() }
        caffeine.set(settings.keepAwake)
        engine.start()

        let t = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in self?.animateSteam() }
        RunLoop.main.add(t, forMode: .common)
        steamTimer = t
    }

    func applicationWillTerminate(_ notification: Notification) {
        caffeine.stop()
        if lastPhase != .rest { integrations.focusOff() }
    }

    // MARK: Engine -> side effects

    private var bag = Set<AnyCancellable>()

    private func engineChanged() {
        let new = engine.phase, old = lastPhase
        lastPhase = new
        refreshTitle()
        guard new != old else { return }

        let focusing: Set<Engine.Phase> = [.focus, .warning, .waiting]
        if focusing.contains(new) && !(old.map(focusing.contains) ?? false) {
            integrations.focusOn(minutes: engine.remaining / 60 + 20)
        }
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
                                                     steamAlpha: settings.keepAwake ? 1 : 0.4)
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
            add(menu, engine.paused ? "Resume" : "Pause", #selector(togglePause))
            add(menu, "Rest now", #selector(restNow))
            add(menu, "Restart focus", #selector(restartFocus))
            menu.addItem(.separator())
        }
        add(menu, "Keep awake", #selector(toggleKeepAwake), checked: settings.keepAwake)
        add(menu, "I'm in a meeting", #selector(toggleManualMeeting), checked: detector.manual)
        if detector.detected {
            menu.addItem(withTitle: "Call detected (mic/camera in use)", action: nil, keyEquivalent: "").isEnabled = false
        }
        menu.addItem(.separator())
        add(menu, "Settings…", #selector(openSettings), key: ",")
        add(menu, "Quit Pomokaffee", #selector(NSApplication.terminate(_:)), key: "q", target: NSApp)
    }

    private func add(_ menu: NSMenu, _ title: String, _ action: Selector, key: String = "",
                     checked: Bool = false, target: AnyObject? = nil) {
        let item = menu.addItem(withTitle: title, action: action, keyEquivalent: key)
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
            w.title = "Pomokaffee Settings"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.center()
            settingsWindow = w
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
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
