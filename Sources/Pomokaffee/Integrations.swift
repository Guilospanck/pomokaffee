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

    // MARK: Focus

    func focusOn(minutes: Int) {
        if settings.shortcutsEnabled { runShortcut(settings.shortcutOn) }
        if settings.slackEnabled {
            slack("dnd.setSnooze", ["num_minutes": String(minutes)])
            slack("users.profile.set", ["profile": #"{"status_text":"Focusing","status_emoji":":apple:"}"#])
        }
    }

    func focusOff() {
        if settings.shortcutsEnabled { runShortcut(settings.shortcutOff) }
        if settings.slackEnabled {
            slack("dnd.endSnooze", [:])
            slack("users.profile.set", ["profile": #"{"status_text":"","status_emoji":""}"#])
        }
    }

    // MARK: Rest

    func runRestScripts() {
        var commands: [String] = []
        if settings.cleanupEnabled { commands.append(settings.cleanupCommand) }
        commands += settings.restScripts.split(whereSeparator: \.isNewline).map(String.init)
        for c in commands where !c.trimmingCharacters(in: .whitespaces).isEmpty {
            queue.async { Self.shell(c) }
        }
    }

    // MARK: Helpers

    private func runShortcut(_ name: String) {
        guard !name.isEmpty else { return }
        queue.async {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            p.arguments = ["run", name]
            p.standardOutput = FileHandle.nullDevice
            p.standardError = FileHandle.nullDevice
            do { try p.run(); p.waitUntilExit() } catch { Log.write("shortcut \(name) failed: \(error)") }
            if p.terminationStatus != 0 { Log.write("shortcut '\(name)' exited \(p.terminationStatus)") }
        }
    }

    private static func shell(_ command: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/zsh")
        p.arguments = ["-ilc", command]  // interactive login: picks up PATH/aliases from .zshrc
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        Log.write("run: \(command)")
        do { try p.run(); p.waitUntilExit(); Log.write("done (\(p.terminationStatus)): \(command)") }
        catch { Log.write("failed: \(command): \(error)") }
    }

    private func slack(_ method: String, _ params: [String: String]) {
        let token = settings.slackToken
        guard !token.isEmpty, let url = URL(string: "https://slack.com/api/\(method)") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var comps = URLComponents()
        comps.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        req.httpBody = comps.percentEncodedQuery?.data(using: .utf8)
        URLSession.shared.dataTask(with: req) { data, _, error in
            if let error { Log.write("slack \(method): \(error)"); return }
            if let data, let s = String(data: data, encoding: .utf8), s.contains("\"ok\":false") {
                Log.write("slack \(method): \(s)")
            }
        }.resume()
    }
}
