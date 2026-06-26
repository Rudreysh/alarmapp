import Foundation

/// Turns the user's self-estimated daily screen time + snooze habit into the
/// numbers shown on the combined "daily loop" insight screen. Deliberately
/// conservative and derived ONLY from the user's own answers (no scary external
/// claims) — the screen frames the total as time they could reclaim.
struct DailyLoopCalculator {
    let snoozesPerMorning: Int      // 0–8
    let dailyScreenHours: Double    // 0–8 (8 = "8+")
    let snoozeMinutes: Int = 9

    /// Minutes lost to snoozing each morning.
    var dailySnoozeMinutes: Int { snoozesPerMorning * snoozeMinutes }

    /// Whole hours/minutes of daily scrolling, for display.
    var scrollHoursWhole: Int { Int(dailyScreenHours) }
    var scrollMinutesRemainder: Int { Int((dailyScreenHours - Double(Int(dailyScreenHours))) * 60) }

    /// Total reclaimable minutes per day. We don't assume the user reclaims ALL
    /// scrolling — Alarmo's friction targets the mindless portion. Use a modest
    /// 40% of scroll time + all snooze time.
    private var reclaimableDailyMinutes: Double {
        Double(dailySnoozeMinutes) + (dailyScreenHours * 60.0 * 0.40)
    }

    var reclaimableHoursPerMonth: Int {
        Int((reclaimableDailyMinutes * 30.0) / 60.0)
    }

    var reclaimableHoursPerYear: Int {
        Int((reclaimableDailyMinutes * 365.0) / 60.0)
    }

    var reclaimableDaysPerYear: Double {
        reclaimableDailyMinutes * 365.0 / 60.0 / 24.0
    }

    /// 0…1 share of a 16-hour waking day spent in the loop — drives the dot grid.
    var dailyLoopFraction: Double {
        let lostHours = Double(dailySnoozeMinutes) / 60.0 + dailyScreenHours
        return min(1.0, lostHours / 16.0)
    }

    var screenTimeLabel: String {
        if dailyScreenHours >= 8 { return "8+ hours" }
        if scrollMinutesRemainder == 0 { return "\(scrollHoursWhole) hours" }
        return "\(scrollHoursWhole)h \(scrollMinutesRemainder)m"
    }

    var screenTimeContextString: String {
        switch dailyScreenHours {
        case ..<2: return "Lighter than most — let's keep it that way."
        case ..<4: return "Around average. Small friction goes a long way."
        case ..<6: return "That's a big slice of your free time."
        default: return "That's most of an evening, every single day."
        }
    }
}
