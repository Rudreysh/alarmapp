import Foundation

/// The redesigned onboarding tells one story across two pillars — stop snoozing
/// (alarm + missions) and stop scrolling (app blocking + mission unlock).
///
/// Flow shape: Hook → Alarm diagnosis (3 Qs) → Blocking transition + diagnosis
/// (3 Qs) → combined insight + hope → Setup (alarm/mission/blocking/sound) →
/// Permissions → Plan summary → Paywall.
enum OnboardingStep: Int, CaseIterable {
    case intro = 1
    case namePrompt = 2

    // Alarm diagnosis
    case morningProblem = 3
    case snoozeFrequency = 4
    case alarmDifficulty = 5

    // App-blocking transition + diagnosis
    case blockingTransition = 6
    case appsWhen = 7
    case screenTime = 8
    case appsToBlock = 9

    // Insight (split: daily story, then lifetime story) + hope
    case dailyLoopInsight = 10
    case lifetimeInsight = 11
    case hopePillars = 12

    // Setup
    case setTime = 13
    case missionType = 14
    case blockingSchedule = 15
    case soundSelection = 16
    case soundVolume = 17

    // Permissions
    case alarmPermission = 18
    case screenTimeAccess = 19
    case cameraAccess = 20

    // Finish
    case planSummary = 21
    case trackingExplainer = 22
    case paywall = 23

    func next() -> OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }

    /// Total used by progress indicators. Kept stable so the bar advances
    /// monotonically even when the camera step is skipped.
    static let progressTotal = OnboardingStep.allCases.count
}
