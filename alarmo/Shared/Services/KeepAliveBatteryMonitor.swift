import Foundation
import UIKit

/// Pure instrumentation (no behavior change) that quantifies the battery cost of the
/// silent keep-alive audio on a real device. It records every keep-alive start/stop
/// (with the battery level + charging state at each edge) and stores the latest
/// MetricKit time/CPU snapshot, so Settings → Alarm → Battery Monitor can show:
///   • how long the keep-alive actually ran (app-observed, a lower bound),
///   • the authoritative system numbers from MetricKit (`cumulativeBackgroundAudioTime`),
///   • a coarse "% battery drained per hour while keep-alive active" estimate.
///
/// Battery granularity is ~5% and other apps confound the reading, so the per-hour
/// estimate is a trend signal, not a precise figure — MetricKit's background-audio
/// time is the trustworthy number.
@MainActor
final class KeepAliveBatteryMonitor {
    static let shared = KeepAliveBatteryMonitor()

    struct Session: Codable {
        var start: Date
        var end: Date?
        var startBattery: Float   // 0...1, -1 = unknown
        var endBattery: Float
        var startCharging: Bool
        var endCharging: Bool
        var startReason: String
        var endReason: String

        var duration: TimeInterval { (end ?? Date()).timeIntervalSince(start) }
        var isCharging: Bool { startCharging || endCharging }
    }

    struct MetricKitSnapshot: Codable {
        var capturedAt: Date
        var periodBegin: Date
        var periodEnd: Date
        var backgroundAudioHours: Double
        var backgroundHours: Double
        var foregroundHours: Double
        var cpuSeconds: Double
    }

    struct RecentRow: Identifiable {
        let id: Int
        let when: String
        let duration: String
        let batteryDelta: String
        let charging: Bool
    }

    struct Report {
        var batteryLevelPct: Int          // -1 = unknown
        var batteryStateText: String
        var activeNow: Bool
        var keepAliveHours24h: Double
        var sessions24h: Int
        var estDrainPerHourPct: Double?   // nil if insufficient unplugged data
        var estSampleCount: Int
        var metricKit: MetricKitSnapshot?
        var recent: [RecentRow]
    }

    private let defaults = UserDefaults.standard
    private let sessionsKey = "keepAlive.battery.sessions.v1"
    private let metricKitKey = "keepAlive.battery.metrickit.v1"
    private let maxSessions = 80

    private(set) var sessions: [Session] = []
    private var activeIndex: Int?

    private init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        load()
    }

    // MARK: - Keep-alive lifecycle hooks

    func recordStart(reason: String) {
        // Defensively close any dangling open session.
        if let idx = activeIndex, sessions.indices.contains(idx), sessions[idx].end == nil {
            finishSession(at: idx, reason: "superseded")
        }
        sessions.append(
            Session(
                start: Date(),
                end: nil,
                startBattery: currentBattery(),
                endBattery: -1,
                startCharging: chargingNow(),
                endCharging: false,
                startReason: reason,
                endReason: ""
            )
        )
        if sessions.count > maxSessions {
            sessions.removeFirst(sessions.count - maxSessions)
        }
        activeIndex = sessions.count - 1
        save()
    }

    func recordStop(reason: String) {
        guard let idx = activeIndex, sessions.indices.contains(idx), sessions[idx].end == nil else { return }
        finishSession(at: idx, reason: reason)
        activeIndex = nil
        save()
    }

    private func finishSession(at idx: Int, reason: String) {
        sessions[idx].end = Date()
        sessions[idx].endBattery = currentBattery()
        sessions[idx].endCharging = chargingNow()
        sessions[idx].endReason = reason
    }

    // MARK: - MetricKit

    func recordMetricKit(_ snapshot: MetricKitSnapshot) {
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: metricKitKey)
        }
    }

    private var latestMetricKit: MetricKitSnapshot? {
        guard let data = defaults.data(forKey: metricKitKey) else { return nil }
        return try? JSONDecoder().decode(MetricKitSnapshot.self, from: data)
    }

    // MARK: - Report

    func makeReport() -> Report {
        let now = Date()
        let cutoff = now.addingTimeInterval(-24 * 3600)
        let window = sessions.filter { ($0.end ?? now) >= cutoff }

        let hours24h = window.reduce(0.0) { $0 + max(0, $1.duration) } / 3600.0

        // Estimate drain: completed, fully-unplugged sessions ≥ 15 min where the
        // battery actually dropped. Excludes any session that touched a charger.
        var perHourSamples: [Double] = []
        for s in sessions where s.end != nil && !s.isCharging
            && s.startBattery >= 0 && s.endBattery >= 0
            && s.duration >= 900 && s.endBattery < s.startBattery {
            let drop = Double(s.startBattery - s.endBattery) * 100.0
            perHourSamples.append(drop / (s.duration / 3600.0))
        }
        let estDrain = perHourSamples.isEmpty
            ? nil
            : perHourSamples.reduce(0, +) / Double(perHourSamples.count)

        let recent = sessions.suffix(12).reversed().enumerated().map { (i, s) -> RecentRow in
            RecentRow(
                id: i,
                when: Self.shortDateFormatter.string(from: s.start),
                duration: Self.formatDuration(s.duration),
                batteryDelta: Self.formatBatteryDelta(s),
                charging: s.isCharging
            )
        }

        return Report(
            batteryLevelPct: currentBattery() >= 0 ? Int((currentBattery() * 100).rounded()) : -1,
            batteryStateText: stateText(),
            activeNow: activeIndex != nil,
            keepAliveHours24h: hours24h,
            sessions24h: window.count,
            estDrainPerHourPct: estDrain,
            estSampleCount: perHourSamples.count,
            metricKit: latestMetricKit,
            recent: Array(recent)
        )
    }

    func reset() {
        sessions = []
        activeIndex = nil
        defaults.removeObject(forKey: sessionsKey)
        defaults.removeObject(forKey: metricKitKey)
    }

    // MARK: - Battery helpers

    private func currentBattery() -> Float {
        let level = UIDevice.current.batteryLevel
        return level >= 0 ? level : -1
    }

    private func chargingNow() -> Bool {
        let state = UIDevice.current.batteryState
        return state == .charging || state == .full
    }

    private func stateText() -> String {
        switch UIDevice.current.batteryState {
        case .charging: return "Charging"
        case .full: return "Full"
        case .unplugged: return "On battery"
        default: return "Unknown"
        }
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(sessions) {
            defaults.set(data, forKey: sessionsKey)
        }
    }

    private func load() {
        guard let data = defaults.data(forKey: sessionsKey),
              let decoded = try? JSONDecoder().decode([Session].self, from: data) else { return }
        sessions = decoded
        // Any session still open after a relaunch was ended by app termination at an
        // unknown time. Close it at its start (0 duration) so it never inflates totals;
        // MetricKit's background-audio time is the authoritative figure for those gaps.
        for i in sessions.indices where sessions[i].end == nil {
            sessions[i].end = sessions[i].start
            sessions[i].endBattery = sessions[i].startBattery
            sessions[i].endReason = "terminated-or-relaunch"
        }
        activeIndex = nil
    }

    // MARK: - Formatting

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, HH:mm"
        return f
    }()

    static func formatDuration(_ seconds: TimeInterval) -> String {
        let s = Int(max(0, seconds))
        let h = s / 3600, m = (s % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m" }
        return "\(s)s"
    }

    private static func formatBatteryDelta(_ s: Session) -> String {
        guard s.startBattery >= 0, s.endBattery >= 0 else { return "—" }
        let from = Int((s.startBattery * 100).rounded())
        let to = Int((s.endBattery * 100).rounded())
        let delta = to - from
        let sign = delta > 0 ? "+" : ""
        return "\(from)% → \(to)% (\(sign)\(delta)%)"
    }
}
