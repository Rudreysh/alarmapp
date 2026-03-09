import SwiftUI
import Combine

// MARK: - Lap Entry

struct LapEntry: Identifiable {
    let id = UUID()
    let number: Int
    let lapTime: TimeInterval      // time for just this lap
    let totalTime: TimeInterval    // cumulative elapsed at this lap
    let timestamp: Date
}

// MARK: - Stopwatch Session (History)

struct StopwatchSession: Identifiable, Codable {
    var id: UUID = UUID()
    var label: String
    var startedAt: Date
    var endedAt: Date
    var totalDuration: TimeInterval
    var lapCount: Int
    var bestLap: TimeInterval?
}

// MARK: - Stopwatch Mode

enum StopwatchRecordMode {
    case lap    // each mark shows time since last mark
    case split  // each mark shows cumulative total
}

// MARK: - Engine

class StopwatchEngine: ObservableObject {

    enum State { case idle, running, paused }

    @Published var elapsed: TimeInterval = 0
    @Published var state: State = .idle
    @Published var laps: [LapEntry] = []
    @Published var sessions: [StopwatchSession] = []

    var recordMode: StopwatchRecordMode = .lap

    // Target / interval alerts
    var targetTime: TimeInterval? = nil
    var alertInterval: TimeInterval? = nil
    
    private let preferences: AppPreferences
    private let soundPlayer = SoundPlayer()

    private var startDate: Date?
    private var accumulatedTime: TimeInterval = 0
    private var lastLapElapsed: TimeInterval = 0
    private var timerCancellable: AnyCancellable?
    private var firedAlerts: Set<Double> = []
    private var sessionStartDate: Date?

    init(preferences: AppPreferences = AppPreferences()) {
        self.preferences = preferences
    }

    // MARK: - Public API

    var currentLapTime: TimeInterval {
        elapsed - lastLapElapsed
    }

    var bestLap: LapEntry? {
        laps.min(by: { $0.lapTime < $1.lapTime })
    }

    var worstLap: LapEntry? {
        laps.max(by: { $0.lapTime < $1.lapTime })
    }

    var isBestLap: Bool {
        guard laps.count >= 2, let best = bestLap else { return false }
        return laps.first?.id == best.id
    }

    func start() {
        guard state != .running else { return }
        if state == .idle {
            sessionStartDate = Date()
            firedAlerts = []
        }
        startDate = Date()
        state = .running
        startTick()
    }

    func pause() {
        guard state == .running else { return }
        accumulatedTime = elapsed
        state = .paused
        timerCancellable?.cancel()
    }

    func resume() {
        guard state == .paused else { return }
        startDate = Date()
        state = .running
        startTick()
    }

    func stop() {
        timerCancellable?.cancel()
        if elapsed > 1 {
            let session = StopwatchSession(
                label: "Stopwatch",
                startedAt: sessionStartDate ?? Date().addingTimeInterval(-elapsed),
                endedAt: Date(),
                totalDuration: elapsed,
                lapCount: laps.count,
                bestLap: bestLap?.lapTime
            )
            sessions.insert(session, at: 0)
            persistSessions()
        }
        reset()
    }

    func recordLap() {
        guard state == .running || state == .paused else { return }
        let lapTime = elapsed - lastLapElapsed
        let entry = LapEntry(
            number: laps.count + 1,
            lapTime: lapTime,
            totalTime: elapsed,
            timestamp: Date()
        )
        laps.insert(entry, at: 0) // newest first
        lastLapElapsed = elapsed
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func clearHistory() {
        sessions = []
        persistSessions()
    }

    // MARK: - Private

    private func reset() {
        elapsed = 0
        accumulatedTime = 0
        lastLapElapsed = 0
        startDate = nil
        laps = []
        state = .idle
        firedAlerts = []
    }

    private func startTick() {
        timerCancellable = Timer.publish(every: 0.01, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    private func tick() {
        guard let start = startDate else { return }
        elapsed = accumulatedTime + Date().timeIntervalSince(start)
        checkAlerts()
    }

    private func checkAlerts() {
        if let target = targetTime, elapsed >= target, !firedAlerts.contains(target) {
            firedAlerts.insert(target)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            soundPlayer.playOnce(resourceName: preferences.stopwatchSoundName, volume: 1.0)
            print("[StopwatchEngine] 🔔 Target Alert Fired: \(target)s")
        }
        if let interval = alertInterval, interval > 0 {
            let bucket = floor(elapsed / interval) * interval
            if bucket > 0 && !firedAlerts.contains(bucket) {
                firedAlerts.insert(bucket)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                soundPlayer.playOnce(resourceName: preferences.stopwatchSoundName, volume: 0.8)
                print("[StopwatchEngine] 🔔 Interval Alert Fired: \(bucket)s")
            }
        }
    }

    // MARK: - Persistence

    private func persistSessions() {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: "sw_sessions")
        }
    }

    func loadSessions() {
        if let data = UserDefaults.standard.data(forKey: "sw_sessions"),
           let decoded = try? JSONDecoder().decode([StopwatchSession].self, from: data) {
            sessions = decoded
        }
    }
}

// MARK: - Formatting Helper

func swFormatTime(_ t: TimeInterval, showHundredths: Bool = true) -> String {
    let totalCentiseconds = Int(t * 100)
    let hours = totalCentiseconds / 360000
    let minutes = (totalCentiseconds % 360000) / 6000
    let seconds = (totalCentiseconds % 6000) / 100
    let centis = totalCentiseconds % 100
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }
    if showHundredths {
        return String(format: "%02d:%02d.%02d", minutes, seconds, centis)
    }
    return String(format: "%02d:%02d", minutes, seconds)
}
