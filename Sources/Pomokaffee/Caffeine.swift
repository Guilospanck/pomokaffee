import Foundation

/// Keep-awake: runs `caffeinate -disu`, same flags as the `kaffee` script.
final class Caffeine {
    private var process: Process?

    var isRunning: Bool { process?.isRunning ?? false }

    func set(_ on: Bool) {
        on ? start() : stop()
    }

    private func start() {
        guard !isRunning else { return }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        p.arguments = ["-disu"]
        do { try p.run(); process = p } catch { Log.write("caffeinate failed: \(error)") }
    }

    func stop() {
        process?.terminate()
        process = nil
    }
}
