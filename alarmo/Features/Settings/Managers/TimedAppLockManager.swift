import Foundation
import Combine

/// Standalone "block these apps for X hours" lock, independent of the Pomodoro timer.
///
/// The lock is enforced by the same `ManagedSettings` shield used for focus blocking.
/// That shield **persists across app relaunches and device reboots** until explicitly
/// cleared, so the lock survives force-quit — the app only needs to run to RELEASE it
/// when the time is up (or when an allowed early-stop happens). If the app is never
/// reopened after expiry, the apps simply stay blocked until it is, which is the safe
/// direction for a "no escape" commitment.
///
/// iOS limits (see also the in-app lockdown guidance): a determined user can still
/// revoke Screen Time access or delete the app to drop the shield. Phase C adds
/// Keychain reinstall-resume + tamper detection to make that as hard as iOS allows.
@MainActor
final class TimedAppLockManager: ObservableObject {
    static let shared = TimedAppLockManager()

    /// How hard it is to stop the lock before the timer runs out.
    enum Strictness: String, Codable, CaseIterable {
        case flexible   // stop anytime
        case committed  // complete a mission to stop early
        case locked     // no escape until the timer ends
    }

    struct LockState: Codable {
        var startedAt: Date
        var lockedUntil: Date
        var blockListId: String
        var blockListName: String
        var selectionData: Data
        var adultBlockingEnabled: Bool
        var strictness: Strictness
        var missions: [UnblockChallenge]
        var note: String
    }

    @Published private(set) var state: LockState?
    /// Bumped every second while active so countdown views refresh.
    @Published private(set) var tickToken: Int = 0

    private let defaults = UserDefaults.standard
    private let stateKey = "timedAppLock.state.v1"
    private var tickTimer: Timer?

    private init() {
        load()
    }

    // MARK: - Derived

    var isActive: Bool {
        guard let s = state else { return false }
        return Date() < s.lockedUntil
    }

    var remaining: TimeInterval {
        guard let s = state else { return 0 }
        return max(0, s.lockedUntil.timeIntervalSinceNow)
    }

    /// Whether the user is allowed to end the lock right now (before time is up, an
    /// allowed early-stop depends on strictness; a completed mission is passed in).
    func canStopNow(missionCompleted: Bool) -> Bool {
        guard let s = state else { return true }
        if Date() >= s.lockedUntil { return true }
        switch s.strictness {
        case .flexible: return true
        case .committed: return missionCompleted
        case .locked: return false
        }
    }

    // MARK: - Lifecycle

    func start(
        blockList: AppList,
        duration: TimeInterval,
        strictness: Strictness,
        missions: [UnblockChallenge],
        note: String
    ) {
        let now = Date()
        state = LockState(
            startedAt: now,
            lockedUntil: now.addingTimeInterval(duration),
            blockListId: blockList.id.uuidString,
            blockListName: blockList.name,
            selectionData: blockList.selectionData,
            adultBlockingEnabled: blockList.adultBlockingEnabled,
            strictness: strictness,
            missions: missions.filter { $0 != .off },
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        persist()
        applyShield()
        startTicking()
    }

    /// Attempt to end the lock early. Returns true if the lock was released.
    @discardableResult
    func requestStop(missionCompleted: Bool) -> Bool {
        guard canStopNow(missionCompleted: missionCompleted) else { return false }
        clear()
        return true
    }

    /// Called on app launch — re-apply the shield if still within the window, or
    /// release it if the window already passed while the app was away.
    func restoreOnLaunch() {
        guard let s = state else { return }
        if Date() >= s.lockedUntil {
            clear()
        } else {
            applyShield()
            startTicking()
        }
    }

    // MARK: - Shield

    private func applyShield() {
        guard let s = state else { return }
        BlockingManager.shared.applyBlocking(
            selectionData: s.selectionData,
            mockAppIDs: [],
            mockCategoryIDs: [],
            adultBlockingEnabled: s.adultBlockingEnabled,
            label: "Timed Lock — \(s.blockListName)"
        )
    }

    private func clear() {
        state = nil
        defaults.removeObject(forKey: stateKey)
        stopTicking()
        BlockingManager.shared.clearBlocking()
    }

    // MARK: - Ticking

    private func startTicking() {
        stopTicking()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        tickTimer = timer
    }

    private func stopTicking() {
        tickTimer?.invalidate()
        tickTimer = nil
    }

    private func tick() {
        tickToken &+= 1
        if let s = state, Date() >= s.lockedUntil {
            clear()
        }
    }

    // MARK: - Persistence

    private func persist() {
        guard let s = state, let data = try? JSONEncoder().encode(s) else { return }
        defaults.set(data, forKey: stateKey)
    }

    private func load() {
        guard let data = defaults.data(forKey: stateKey),
              let decoded = try? JSONDecoder().decode(LockState.self, from: data) else { return }
        state = decoded
    }

    static func formatRemaining(_ seconds: TimeInterval) -> String {
        let s = Int(max(0, seconds.rounded()))
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%02d:%02d", m, sec)
    }
}
