import Foundation

struct SnoozeCalculator {
    let snoozesPerMorning: Int   // 1–8
    let userAge: Int             // 16–60
    let snoozeMinutes: Int = 9
    let lifeExpectancy: Int = 80
    let daysPerYear: Int = 365

    var dailyMinutesLost: Int {
        snoozesPerMorning * snoozeMinutes
    }

    var hoursLostPerYear: Int {
        Int((Double(dailyMinutesLost) * Double(daysPerYear)) / 60)
    }

    var daysLostPerYear: Double {
        Double(dailyMinutesLost) * Double(daysPerYear) / 60 / 24
    }

    var hoursLostPerMonth: Double {
        Double(dailyMinutesLost) * 30 / 60
    }

    var yearsRemaining: Int {
        max(0, lifeExpectancy - userAge)
    }

    var lifetimeHoursLost: Double {
        Double(dailyMinutesLost) * Double(daysPerYear) * Double(yearsRemaining) / 60
    }

    var lifetimeYearsLost: Double {
        lifetimeHoursLost / 8760
    }

    var lifetimeDaysLost: Int {
        Int(lifetimeHoursLost / 24)
    }

    var booksCouldRead: Int { Int(lifetimeHoursLost / 6) }
    var workoutsCouldDo: Int { Int(lifetimeHoursLost / 0.75) }
    var calmMornings: Int { Int(Double(daysPerYear) * Double(yearsRemaining) * 0.85) }

    var morningsLostPerYear: Int {
        min(daysPerYear, Int(Double(daysPerYear) * Double(dailyMinutesLost) / (16.0 * 60.0) * 10))
    }

    var dailyContextString: String {
        switch snoozesPerMorning {
        case 1: return "That's a hot shower and a quiet coffee."
        case 2: return "That's a proper breakfast and a short walk."
        case 3: return "That's a shower, breakfast, and time to breathe."
        case 4: return "That's a full workout and a shower."
        case 5: return "That's almost a full extra hour every morning."
        case 6: return "That's more than an hour — every single day."
        case 7: return "That's a full morning routine, twice over."
        default: return "That's more than 90 minutes of real life, daily."
        }
    }
}

