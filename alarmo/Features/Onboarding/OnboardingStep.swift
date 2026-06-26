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

    // Combined insight + hope
    case dailyLoopInsight = 10
    case hopePillars = 11

    // Setup
    case setTime = 12
    case missionType = 13
    case blockingSchedule = 14
    case soundSelection = 15
    case soundVolume = 16

    // Permissions
    case alarmPermission = 17
    case screenTimeAccess = 18
    case cameraAccess = 19

    // Finish
    case planSummary = 20
    case trackingExplainer = 21
    case paywall = 22

    func next() -> OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }

    /// Total used by progress indicators. Kept stable so the bar advances
    /// monotonically even when the camera step is skipped.
    static let progressTotal = OnboardingStep.allCases.count
}
