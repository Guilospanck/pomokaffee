import Foundation
import UserNotifications

/// Last run failure of each command row, shown under the row in Settings.
/// Tied to the command text, so editing the command hides a stale message.
final class CommandStatus: ObservableObject {
    static let shared = CommandStatus()
    struct Failure: Equatable { let command: String; let message: String }
    @Published private(set) var failures: [UUID: Failure] = [:]

    func set(_ id: UUID, command: String, message: String?) {
        DispatchQueue.main.async {
            if let message { self.failures[id] = Failure(command: command, message: message) }
            else { self.failures.removeValue(forKey: id) }
        }
    }
}

/// Collects the tail of a child process's stderr without risking a full pipe.
final class StderrTail {
    let pipe = Pipe()
    private let lock = NSLock()
    private var data = Data()

    init() {
        pipe.fileHandleForReading.readabilityHandler = { [weak self] h in
            let d = h.availableData
            guard let self else { return }
            if d.isEmpty { h.readabilityHandler = nil; return }
            lock.lock(); data.append(d); if data.count > 4096 { data = data.suffix(4096) }; lock.unlock()
        }
    }

    /// Last non-empty stderr line. Call after the process exited.
    var lastLine: String? {
        Thread.sleep(forTimeInterval: 0.05)
        pipe.fileHandleForReading.readabilityHandler = nil
        lock.lock(); defer { lock.unlock() }
        return String(decoding: data, as: UTF8.self).split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }.last { !$0.isEmpty }
    }
}

enum CommandCheck {
    /// The program the command starts with, skipping `VAR=value` prefixes. Nil when it cannot be judged
    /// (quotes, subshells, expansions).
    static func program(of command: String) -> String? {
        for tok in command.split(whereSeparator: \.isWhitespace) {
            let t = String(tok)
            if t.range(of: "^[A-Za-z_][A-Za-z0-9_]*=", options: .regularExpression) != nil { continue }
            if let c = t.first, "$({!`\"'\\".contains(c) { return nil }
            return t
        }
        return nil
    }

    /// Message if the command's program does not exist in the login shell; nil if it does or cannot be judged.
    static func missing(_ command: String) async -> String? {
        guard let word = program(of: command) else { return nil }
        let name = (word as NSString).expandingTildeInPath
        return await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .utility).async {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/bin/zsh")
                p.arguments = ["-ilc", "command -v -- \"$1\"", "pomokaffee", name]  // same shell the commands run in
                p.standardOutput = FileHandle.nullDevice
                p.standardError = FileHandle.nullDevice
                do { try p.run(); p.waitUntilExit() } catch { cont.resume(returning: nil); return }
                cont.resume(returning: p.terminationStatus == 0 ? nil : "Command not found: \(word)")
            }
        }
    }

    /// Human message for a command that exited with `status`.
    static func failure(command: String, status: Int32, stderr: String?) -> String {
        switch status {
        case 127: return "Command not found: \(program(of: command) ?? command)"
        case 126: return "Cannot run it: not executable"
        default: return stderr.map { "Failed (exit \(status)): \($0)" } ?? "Failed with exit code \(status)"
        }
    }

    /// Runs after a command finished: records or clears the failure and notifies on failure.
    static func report(_ item: CommandItem, status: Int32, stderr: String?, what: String) {
        guard status != 0 else {
            CommandStatus.shared.set(item.id, command: item.command, message: nil)
            return
        }
        let message = failure(command: item.command, status: status, stderr: stderr)
        Log.write("\(what) failed (\(status)): \(item.command): \(message)")
        CommandStatus.shared.set(item.id, command: item.command, message: message)
        Notifier.post("\(what) failed", "\(item.command)\n\(message)")
    }
}

enum Notifier {
    private static var recent: [String: Date] = [:]

    /// Shows a notification. The same one is not repeated within a minute. Does nothing outside the .app bundle.
    static func post(_ title: String, _ body: String) {
        guard Bundle.main.bundleURL.pathExtension == "app" else { return }
        DispatchQueue.main.async {
            let key = title + body
            if let t = recent[key], Date().timeIntervalSince(t) < 60 { return }
            recent[key] = Date()
            let center = UNUserNotificationCenter.current()
            center.requestAuthorization(options: [.alert]) { granted, _ in
                guard granted else { return }
                let c = UNMutableNotificationContent()
                c.title = title
                c.body = body
                center.add(UNNotificationRequest(identifier: UUID().uuidString, content: c, trigger: nil))
            }
        }
    }
}
