import Foundation

enum AlarmFeatureFlags {
    /// Experimental best-effort output-volume floor adjustment using MPVolumeView.
    /// Keep disabled if App Store behavior is undesirable for a release branch.
    /// When false, the app never moves a hidden MPVolumeView slider to fight volume-down.
    /// Users adjust volume via hardware buttons; low volume triggers warning + AlarmKit recovery.
    static let experimentalMPVolumeOutputFloor = true

    /// Locked/background alarm policy for this branch:
    /// keep AlarmKit as the first sound owner and disable AlarmKit respawn churn.
    /// If the user/system suppresses AlarmKit sound (slide-to-stop, side button,
    /// volume drop, interruption), the app engine may take over after verification.
    static let alarmKitPrimaryOwnerNoRespawn = true

    /// After AlarmKit is likely suppressed, start the app engine immediately and
    /// verify audibility instead of scheduling replacement AlarmKit surfaces.
    static let appEngineTakesOverAfterAlarmKitSuppression = true

    /// Suppression-triggered takeover stability policy:
    /// AlarmKit is always the initial sound at fire time. When the user suppresses
    /// it (side button / volume button / slide-to-stop) while backgrounded+locked,
    /// iOS silences AlarmKit and the app engine takes over. This flag makes that
    /// takeover ALWAYS attempt playback instead of refusing when media volume is
    /// low:
    ///   • No volume-floor pre-check — the engine calls `play()` even at output
    ///     volume 0.0 (`engineInaudibleWhileLockedProven` no longer blocks it).
    ///   • The engine starts near the current (possibly low) media volume and ramps
    ///     up to full over a few seconds, while best-effort raising the system
    ///     output volume so the user eventually hears it loudly.
    ///   • AlarmKit's lock-screen UI is still dismissed ONLY after strict audibility
    ///     verification, and the no-UI watchdog re-alerts AlarmKit if nothing is
    ///     audible — so a brief gap is possible but permanent silence is not.
    /// NOTE: `player.volume` is relative to system output volume; ramping it to 1.0
    /// is only audible if system output > 0. Raising system output in the
    /// background is best-effort (MPVolumeView) and not guaranteed by iOS.
    static let appEngineTakeoverIgnoresVolumeFloor = true
}
