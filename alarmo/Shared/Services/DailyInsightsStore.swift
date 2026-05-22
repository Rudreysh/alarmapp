import Foundation

struct DailyInsight: Codable, Identifiable, Equatable {
    let id: Int
    let title: String
    let description: String
}

final class DailyInsightsStore {
    static let shared = DailyInsightsStore()

    private let fileName = "daily_insights_db.json"
    private let seedResourceName = "daily_insights_seed"
    private let seedResourceExtension = "json"
    private let queue = DispatchQueue(label: "com.alarmo.daily-insights-store")

    private var insights: [DailyInsight] = []

    private init() {
        loadOrSeedDatabase()
    }

    func allInsights() -> [DailyInsight] {
        queue.sync { insights }
    }

    func randomInsight(excluding excludedID: Int? = nil) -> DailyInsight {
        queue.sync {
            let candidates: [DailyInsight]
            if let excludedID {
                let filtered = insights.filter { $0.id != excludedID }
                candidates = filtered.isEmpty ? insights : filtered
            } else {
                candidates = insights
            }
            return candidates.randomElement() ?? fallbackInsights[0]
        }
    }

    func motivationLine(for scenario: AppNotificationScenario) -> String {
        let insight = randomInsight()
        let advantage = "\(insight.title): \(insight.description)"

        switch scenario {
        case .alarmRing:
            return "Wake up early now. \(advantage)"
        case .alarmSnooze:
            return "Get up now instead of snoozing. \(advantage)"
        case .alarmTomorrowCheck:
            return "Set tomorrow's alarm and wake at a consistent time. \(advantage)"
        case .bedtimeReminder:
            return "Sleep at the same time tonight so waking early is easier. \(advantage)"
        case .missedAlarmFollowUp:
            return "Reset today: sleep and wake at the same time to rebuild momentum. \(advantage)"
        case .taskReminder, .taskOverdue:
            return "Do this task now to build consistency. \(advantage)"
        case .habitReminder:
            return "Complete this habit now and protect your morning routine. \(advantage)"
        case .pomodoroFocusStart, .pomodoroFocusComplete, .pomodoroBreakStart, .pomodoroBreakComplete,
                .stopwatchTargetReached, .countdownFinished, .countdownCycleRepeat:
            return "Stay consistent today. \(advantage)"
        }
    }

    private func loadOrSeedDatabase() {
        if let persisted = loadFromDisk(), !persisted.isEmpty {
            queue.sync { insights = persisted }
            return
        }

        if let seeded = loadFromBundle(), !seeded.isEmpty {
            queue.sync { insights = seeded }
            saveToDisk(seeded)
            return
        }

        queue.sync { insights = fallbackInsights }
        saveToDisk(fallbackInsights)
    }

    private func loadFromDisk() -> [DailyInsight]? {
        guard let url = databaseURL(),
              let data = try? Data(contentsOf: url),
              let parsed = try? JSONDecoder().decode([DailyInsight].self, from: data) else {
            return nil
        }
        return parsed
    }

    private func loadFromBundle() -> [DailyInsight]? {
        guard let url = Bundle.main.url(forResource: seedResourceName, withExtension: seedResourceExtension),
              let data = try? Data(contentsOf: url),
              let parsed = try? JSONDecoder().decode([DailyInsight].self, from: data) else {
            return nil
        }
        return parsed
    }

    private func saveToDisk(_ values: [DailyInsight]) {
        guard let url = databaseURL(),
              let data = try? JSONEncoder().encode(values) else {
            return
        }
        try? data.write(to: url, options: .atomic)
    }

    private func databaseURL() -> URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = appSupport.appendingPathComponent("Awayk", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir.appendingPathComponent(fileName, isDirectory: false)
        } catch {
            return nil
        }
    }

    private let fallbackInsights: [DailyInsight] = [
        .init(id: 1, title: "Brain Reset", description: "Waking early aligns with natural circadian rhythms that optimize cognitive performance."),
        .init(id: 2, title: "Cortisol Peak", description: "Morning cortisol surge increases alertness and helps the brain transition to focus mode."),
        .init(id: 3, title: "Circadian Sync", description: "Consistent wake time strengthens the brain's internal biological clock."),
        .init(id: 4, title: "Sleep Quality", description: "Consistent wake time improves slow-wave sleep efficiency."),
        .init(id: 5, title: "Mental Clarity", description: "Reduced sensory overload early in the day supports clearer neural processing.")
    ]
}
