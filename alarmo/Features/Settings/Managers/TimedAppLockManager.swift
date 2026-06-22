import Foundation
import Combine
import UserNotifications

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
    /// Number of times a Locked/Committed lock was found broken (shield missing or
    /// Screen Time access revoked) while it should have been active — the foundation
    /// for the future penalty/fine feature.
    @Published private(set) var brokenCommitmentCount: Int = 0
    /// Set when a lock survives via the Keychain (e.g. after a reinstall) but the
    /// shield can't be re-applied because Screen Time access isn't granted.
    @Published private(set) var needsReauthToResume = false

    private let defaults = UserDefaults.standard
    private let stateKey = "timedAppLock.state.v1"
    private let keychainAccount = "timedAppLock.state.v1"
    private let brokenKey = "timedAppLock.brokenCommitments.v1"
    private var tickTimer: Timer?

    private init() {
        brokenCommitmentCount = defaults.integer(forKey: brokenKey)
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
        scheduleExpiryNotification()
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
    /// release it if the window already passed while the app was away. Also resumes a
    /// lock that survived an app reinstall via the Keychain.
    func restoreOnLaunch() {
        guard let s = state else { return }
        if Date() >= s.lockedUntil {
            clear()
        } else {
            applyShield()
            scheduleExpiryNotification()
            startTicking()
            verifyIntegrity()
        }
    }

    /// Call when the app returns to the foreground. The 1s tick timer is suspended
    /// while the app is backgrounded, so a lock that expired in the background is
    /// released here, and an active one is re-asserted + tamper-checked.
    func refreshOnForeground() {
        guard let s = state else { return }
        if Date() >= s.lockedUntil {
            clear()
        } else {
            applyShield()
            if tickTimer == nil { startTicking() }
            verifyIntegrity()
        }
    }

    /// Re-assert the shield and detect tampering (shield missing / Screen Time access
    /// revoked) while a lock should be active. Safe to call on every foreground.
    func verifyIntegrity() {
        guard let s = state, Date() < s.lockedUntil else { return }
        #if !targetEnvironment(simulator)
        if !ScreenTimeAuthorizationManager.shared.isAuthorized {
            // The user revoked Screen Time access (or reinstalled) — the shield can't
            // be enforced until access is granted again. Record the broken commitment.
            needsReauthToResume = true
            recordBrokenCommitment()
            return
        }
        #endif
        needsReauthToResume = false
        // Idempotent re-apply ensures the shield is actually in place.
        applyShield()
    }

    private func recordBrokenCommitment() {
        brokenCommitmentCount += 1
        defaults.set(brokenCommitmentCount, forKey: brokenKey)
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
        needsReauthToResume = false
        defaults.removeObject(forKey: stateKey)
        KeychainStore.delete(account: keychainAccount)
        cancelExpiryNotification()
        stopTicking()
        BlockingManager.shared.clearBlocking()
    }

    // MARK: - Expiry notification

    // iOS can't run our code to auto-unblock at expiry without a DeviceActivityMonitor
    // extension, so until that target exists we notify the user to reopen the app,
    // which then releases the lock (refreshOnForeground / restoreOnLaunch). Staying
    // blocked a little past expiry until reopen is the safe direction for a lock.
    private static let expiryNotificationId = "timedAppLock.expiry"

    private func scheduleExpiryNotification() {
        guard let s = state else { return }
        let interval = s.lockedUntil.timeIntervalSinceNow
        cancelExpiryNotification()
        guard interval > 1 else { return }
        let content = UNMutableNotificationContent()
        content.title = "App lock ended"
        content.body = "Your timed lock is over. Open the app to unlock \(s.blockListName)."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(
            identifier: Self.expiryNotificationId,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func cancelExpiryNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [Self.expiryNotificationId]
        )
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
        // Mirror to the Keychain so the lock survives an app reinstall.
        KeychainStore.set(data, account: keychainAccount)
    }

    private func load() {
        // Prefer UserDefaults; fall back to the Keychain copy, which survives an app
        // reinstall (deleting the app does NOT release a still-running lock).
        let data = defaults.data(forKey: stateKey) ?? KeychainStore.get(account: keychainAccount)
        guard let data, let decoded = try? JSONDecoder().decode(LockState.self, from: data) else { return }
        state = decoded
        // Re-seed UserDefaults if we recovered from the Keychain after a reinstall.
        if defaults.data(forKey: stateKey) == nil {
            defaults.set(data, forKey: stateKey)
        }
    }

    static func formatRemaining(_ seconds: TimeInterval) -> String {
        let s = Int(max(0, seconds.rounded()))
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%02d:%02d", m, sec)
    }
}
