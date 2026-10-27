import Foundation

/// Pomodoro state machine. One tick per second.
///
/// focus -> (last 60s) warning -> rest -> focus ...
/// If a meeting is running when the warning or the rest is due, the engine
/// holds in `waiting` until the meeting ends, then gives a fresh 60s warning.
final class Engine: ObservableObject {
    enum Phase { case focus, warning, waiting, rest }

    static let warningLead = 60
    static let postponeSteps = [5, 10]

    @Published private(set) var phase: Phase = .focus
    @Published private(set) var remaining = 0
    @Published private(set) var total = 1
    @Published private(set) var paused = false
    @Published private(set) var postponesUsed = 0

    var isInMeeting: () -> Bool = { false }
    var onChange: () -> Void = {}

    private let settings = Settings.shared
    private var warned = false
    private var timer: Timer?

    var postponeMinutes: Int? {
        postponesUsed < Self.postponeSteps.count ? Self.postponeSteps[postponesUsed] : nil
    }

    func start() {
        startFocus()
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func startFocus() {
        phase = .focus
        total = settings.focusMinutes * 60
        remaining = total
        warned = false
        postponesUsed = 0
        paused = false
        Log.write("focus start total=\(total)s")
        onChange()
    }

    func startRest() {
        phase = .rest
        total = settings.restMinutes * 60
        remaining = total
        paused = false
        onChange()
    }

    func togglePause() {
        guard phase != .rest else { return }
        paused.toggle()
        onChange()
    }

    /// Delays the rest by +5 min, then +10 min. No more after that.
    func postpone() {
        guard phase == .warning, let minutes = postponeMinutes else { return }
        postponesUsed += 1
        phase = .focus
        remaining = minutes * 60
        total = max(total, remaining)
        warned = false
        onChange()
    }

    private func tick() {
        guard !paused else { return }
        switch phase {
        case .focus:
            remaining -= 1
            if remaining <= 0 {
                finishFocus()
            } else if remaining <= Self.warningLead && !warned {
                warned = true
                if !isInMeeting() { phase = .warning }
            }
        case .warning:
            remaining -= 1
            if remaining <= 0 { finishFocus() }
        case .waiting:
            if !isInMeeting() {
                phase = .warning
                remaining = Self.warningLead
            }
        case .rest:
            remaining -= 1
            if remaining <= 0 { startFocus(); return }
        }
        onChange()
    }

    private func finishFocus() {
        if isInMeeting() {
            phase = .waiting
            remaining = 0
        } else {
            startRest()
        }
    }
}
