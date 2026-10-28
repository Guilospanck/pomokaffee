import AppKit
import Foundation

enum Log {
    static let url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/Pomokaffee.log")

    static func write(_ line: String) {
        let text = "\(Date()) \(line)\n"
        if let h = try? FileHandle(forWritingTo: url) {
            h.seekToEndOfFile(); h.write(Data(text.utf8)); try? h.close()
        } else {
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

/// Side effects around focus and rest: macOS Focus (via Shortcuts), Slack, rest scripts.
final class Integrations {
    private let settings = Settings.shared
    private let queue = DispatchQueue(label: "pomokaffee.integrations")
    private let lock = NSLock()
    private var running: [Process] = []
    private var stopping = false

    // MARK: Focus

    func focusOn(minutes: Int) {
        if settings.shortcutsEnabled { runShortcut(Self.shortcutNames[0]) }
        if settings.slackEnabled {
            slack("dnd.setSnooze", ["num_minutes": String(minutes)])
            slack("users.profile.set", ["profile": #"{"status_text":"Focusing","status_emoji":":apple:"}"#])
        }
    }

    /// `wait` blocks until the Shortcut and Slack calls are done; needed when the app is about to exit.
    func focusOff(wait: Bool = false) {
        if settings.shortcutsEnabled { runShortcut(Self.shortcutNames[1], wait: wait) }
        if settings.slackEnabled {
            slack("dnd.endSnooze", [:], wait: wait)
            slack("users.profile.set", ["profile": #"{"status_text":"","status_emoji":""}"#], wait: wait)
        }
    }

    /// Quit cleanup: ends rest commands still running, then turns Focus off and waits for it.
    func shutdown(focusIsOn: Bool) {
        lock.lock(); stopping = true; let procs = running; lock.unlock()
        for p in procs { Self.kill(p) }
        if focusIsOn { focusOff(wait: true) }
    }

    private static func kill(_ p: Process) {
        guard p.isRunning else { return }
        let k = Process()
        k.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        k.arguments = ["-P", String(p.processIdentifier)]
        try? k.run(); k.waitUntilExit()
        p.terminate()
    }

    /// Runs just the Focus Shortcut, ignoring the enable switch. Used when that switch itself is flipped.
    func setShortcutFocus(on: Bool) {
        runShortcut(on ? Self.shortcutNames[0] : Self.shortcutNames[1])
    }

    // MARK: Rest

    func runRestScripts() {
        let items = settings.restItems.filter { $0.enabled && !$0.command.trimmingCharacters(in: .whitespaces).isEmpty }
        for item in items { queue.async { self.shell(item) } }
    }

    // MARK: Helpers

    /// Names of the bundled Shortcuts: [focus on, focus off].
    static let shortcutNames = ["Pomokaffee Focus On", "Pomokaffee Focus Off"]

    /// Where the user creates the Slack app: opens with the two scopes already filled in.
    static let slackAppURL: URL = {
        let manifest = #"{"display_information":{"name":"Pomokaffee"},"oauth_config":{"scopes":{"user":["dnd:write","users.profile:write"]}}}"#
        var c = URLComponents(string: "https://api.slack.com/apps")!
        c.queryItems = [URLQueryItem(name: "new_app", value: "1"), URLQueryItem(name: "manifest_json", value: manifest)]
        return c.url!
    }()

    /// Opens the bundled .shortcut file of every Focus Shortcut not yet in the Shortcuts app.
    /// macOS asks the user to confirm each import with "Add Shortcut"; there is no silent install.
    /// Returns the names that were missing.
    @discardableResult
    static func installMissingShortcuts() -> [String] {
        let missing = missingShortcuts()
        for name in missing {
            guard let url = Bundle.main.url(forResource: name, withExtension: "shortcut") else {
                Log.write("shortcut file for '\(name)' not in app bundle"); continue
            }
            NSWorkspace.shared.open(url)
        }
        return missing
    }

    static func missingShortcuts() -> [String] {
        let list = Process()
        list.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        list.arguments = ["list"]
        let pipe = Pipe()
        list.standardOutput = pipe
        do { try list.run() } catch { Log.write("shortcuts list failed: \(error)"); return [] }
        let out = pipe.fileHandleForReading.readDataToEndOfFile()
        list.waitUntilExit()
        let have = Set(String(decoding: out, as: UTF8.self).split(whereSeparator: \.isNewline).map(String.init))
        return shortcutNames.filter { !have.contains($0) }
    }

    private func runShortcut(_ name: String, wait: Bool = false) {
        guard !name.isEmpty else { return }
        let work = {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            p.arguments = ["run", name]
            p.standardOutput = FileHandle.nullDevice
            p.standardError = FileHandle.nullDevice
            do { try p.run(); p.waitUntilExit() } catch { Log.write("shortcut \(name) failed: \(error)"); return }
            Log.write("shortcut '\(name)' exited \(p.terminationStatus)")
            if p.terminationStatus != 0 {
                Notifier.post("Shortcut failed", "\"\(name)\" did not run. Is it added in the Shortcuts app? Turn on Shortcuts in Settings to add it.")
            }
        }
        if wait { work() } else { queue.async(execute: work) }
    }

    private func shell(_ item: CommandItem) {
        lock.lock(); let skip = stopping; lock.unlock()
        if skip { return }
        let command = item.command
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/zsh")
        p.arguments = ["-ilc", command]  // interactive login: picks up PATH/aliases from .zshrc
        let tail = StderrTail()
        p.standardOutput = FileHandle.nullDevice
        p.standardError = tail.pipe
        Log.write("run: \(CommandCheck.label(command))")
        do {
            try p.run()
            lock.lock(); running.append(p); lock.unlock()
            p.waitUntilExit()
            lock.lock(); running.removeAll { $0 === p }; let quitting = stopping; lock.unlock()
            Log.write("done (\(p.terminationStatus)): \(CommandCheck.label(command))")
            if !quitting { CommandCheck.report(item, status: p.terminationStatus, stderr: tail.lastLine, what: "Rest command") }
        } catch {
            Log.write("failed: \(CommandCheck.label(command)): \(error)")
            CommandCheck.report(item, status: 127, stderr: nil, what: "Rest command")
        }
    }

    private func slack(_ method: String, _ params: [String: String], wait: Bool = false) {
        let token = settings.slackToken
        guard !token.isEmpty, let url = URL(string: "https://slack.com/api/\(method)") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var comps = URLComponents()
        comps.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        req.httpBody = comps.percentEncodedQuery?.data(using: .utf8)
        let done = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: req) { data, _, error in
            defer { done.signal() }
            if let error { Log.write("slack \(method): \(error)"); return }
            if let data, let s = String(data: data, encoding: .utf8), s.contains("\"ok\":false") {
                let code = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String ?? "unknown_error"
                Log.write("slack \(method): \(code)")
                Notifier.post("Slack call failed", "\(code). Check the token in Settings.")
            }
        }.resume()
        if wait { _ = done.wait(timeout: .now() + 3) }
    }
}
