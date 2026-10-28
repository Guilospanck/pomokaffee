import Foundation

/// Keep-awake: runs the selected keep-alive command (default `caffeinate -disu`) until stopped.
final class Caffeine {
    private var process: Process?
    private var running: String?

    var isRunning: Bool { process?.isRunning ?? false }

    /// Starts `item`'s command, restarting if a different one runs. Nil stops.
    func set(_ item: CommandItem?) {
        guard let item else { return stop() }
        let command = item.command
        // Same command already started: don't rerun it, even if it already exited (e.g. `touch`).
        if running == command { return }
        stop()
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/zsh")
        p.arguments = ["-ilc", command]
        let tail = StderrTail()
        p.standardOutput = FileHandle.nullDevice
        p.standardError = tail.pipe
        // stop() clears this handler first, so only an exit we did not cause is reported.
        p.terminationHandler = { proc in
            guard proc.terminationReason == .exit else { return }
            CommandCheck.report(item, status: proc.terminationStatus, stderr: tail.lastLine, what: "Keep-alive command")
        }
        do { try p.run(); process = p; running = command; Log.write("keep alive: \(CommandCheck.label(command))") }
        catch {
            Log.write("keep alive failed: \(CommandCheck.label(command)): \(error)")
            CommandCheck.report(item, status: 127, stderr: nil, what: "Keep-alive command")
        }
    }

    func stop() {
        guard let p = process else { return }
        p.terminationHandler = nil
        // The shell may not exec the command, so end its children too.
        let k = Process()
        k.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        k.arguments = ["-P", String(p.processIdentifier)]
        try? k.run(); k.waitUntilExit()
        p.terminate()
        process = nil
        running = nil
    }
}
