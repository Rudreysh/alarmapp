import Foundation
import SwiftData
import SwiftUI
import Combine

class PlanViewModel: ObservableObject {
    static let habitGoalReachedNotification = Notification.Name("PlanHabitGoalReached")

    private let pointsService = PointsService.shared
    private let settings = SettingsStore.shared
    @Published var selectedDate: Date = Date()
    @Published var isListView: Bool = false
    @Published var showingCreateSheet: Bool = false
    
    // Quick actions state
    @Published var showingActionMenu: Bool = false
    
    // Section Expansion State
    @Published var isAnytimeExpanded = true
    @Published var isHabitsExpanded = true
    @Published var isTasksExpanded = true
    
    // Rate Display Mode
    @Published var showMonthlyRate = false // false = Overall Rate, true = Monthly Rate
    
    @Published var allItems: [PlanItem] = []
    
    private var modelContext: ModelContext?
    
    func setContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    // Logic to determine if an item occurs on the selected date
    func items(from allItems: [PlanItem]) -> [PlanItem] {
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(selectedDate)
        let subtaskIDs = Set(allItems.flatMap { $0.subtasks.map(\.id) })
        
        let result = allItems.filter { item in
            // Filter out subtasks (primary relationship path)
            if item.parentTask != nil { return false }
            // Filter out subtasks (fallback for legacy/misaligned linkage)
            if subtaskIDs.contains(item.id) { return false }
            
            // 1. Repeats: High priority. If it repeats, recurrence rules strictly dictate visibility.
            // (Even if 'anytime' is true, it just means "no specific time" on the occurrence days)
            if item.repeatRule.frequency != .none {
                // Ensure we don't show it before it was created
                if item.createdAt > selectedDate && !calendar.isDate(item.createdAt, inSameDayAs: selectedDate) {
                    return false
                }
                return item.repeatRule.occurs(on: selectedDate, createdAt: item.createdAt)
            }
            
            // 2. Specific Date (Scheduled items)
            if let scheduled = item.scheduledDate, !item.anytime {
                return calendar.isDate(scheduled, inSameDayAs: selectedDate)
            }
            
            // 3. Anytime / Inbox items (Non-repeating)
            // Only show these on "Today". Future dates should be clean unless explicitly scheduled.
            if item.anytime {
                return isToday
            }
            
            return false
        }
        print("[PlanFilter] selectedDate=\(selectedDate) input=\(allItems.count) subtasksDetected=\(subtaskIDs.count) output=\(result.count)")
        return result
    }
    
    func isCompleted(_ item: PlanItem, on date: Date) -> Bool {
        // Check logs
        let calendar = Calendar.current
        return item.completionLogs.contains { log in
            calendar.isDate(log.date, inSameDayAs: date) && log.completed
        }
    }
    
    func toggleComplete(_ item: PlanItem, context: ModelContext) {
        let calendar = Calendar.current
        let todayLog = item.completionLogs.first { log in
            calendar.isDate(log.date, inSameDayAs: selectedDate)
        }
        
        if let log = todayLog {
            // Toggle off
            context.delete(log)
        } else {
            // Toggle on
            let completionDate = calendar.isDateInToday(selectedDate) ? Date() : selectedDate
            let newLog = CompletionLog(date: completionDate, completed: true)
            item.completionLogs.append(newLog)
            
            let event = ActivityEvent(
                domain: item.type == .habit ? .habit : .task,
                entityId: item.id,
                timestampUTC: completionDate,
                status: .completed
            )
            context.insert(event)
            
            // Award points
            if item.type == .habit {
                let streak = calculateStreak(for: item)
                pointsService.habitCompleted(
                    habitId: item.id,
                    habitName: item.title,
                    streakDays: streak
                )
                postHabitGoalReached(item)
            } else {
                pointsService.taskCompleted(
                    taskId: item.id,
                    taskName: item.title,
                    completedBeforeDeadline: didCompleteBeforeDeadline(item, at: completionDate)
                )
            }
        }
        
        item.updatedAt = Date()
        try? context.save()
    }

    func skipHabitForSelectedDate(_ item: PlanItem, context: ModelContext) {
        guard item.type == .habit else { return }

        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: selectedDate)
        let skipTimestamp = calendar.isDateInToday(selectedDate) ? Date() : targetDay

        let existingLogs = item.completionLogs.filter { calendar.isDate($0.date, inSameDayAs: targetDay) }
        existingLogs.forEach { context.delete($0) }

        let skipLog = CompletionLog(date: skipTimestamp, completed: false)
        skipLog.note = CompletionLog.skippedMarker
        item.completionLogs.append(skipLog)

        let event = ActivityEvent(
            domain: .habit,
            entityId: item.id,
            timestampUTC: skipTimestamp,
            status: .skipped,
            metadata: ["source": "manual_habit_skip"]
        )
        context.insert(event)

        if calendar.isDateInToday(selectedDate) {
            pointsService.habitSkipped(habitId: item.id, habitName: item.title)
        }

        item.updatedAt = Date()
        try? context.save()
    }

    func quickIncrement(_ item: PlanItem, context: ModelContext) -> Double {
        return incrementHabit(item, value: defaultIncrement(for: item), context: context)
    }

    func incrementHabit(_ item: PlanItem, value: Double? = nil, context: ModelContext) -> Double {
        let calendar = Calendar.current
        let wasGoalMetBefore = item.isGoalMet()
        let amount = (value != nil && (value ?? 0) > 0) ? (value ?? 1) : defaultIncrement(for: item)

        if let existingLog = item.completionLogs.first(where: { calendar.isDateInToday($0.date) }) {
            if item.metricKind == .time {
                existingLog.durationSeconds = (existingLog.durationSeconds ?? 0) + Int(amount * 60)
            } else {
                existingLog.value = (existingLog.value ?? 0) + amount
            }
            existingLog.completed = item.isGoalMet()
        } else {
            let log = CompletionLog(date: Date(), completed: false)
            if item.metricKind == .time {
                log.durationSeconds = Int(amount * 60)
            } else {
                log.value = amount
            }
            item.completionLogs.append(log)
            log.completed = item.isGoalMet()
        }

        let isGoalMetNow = item.isGoalMet()
        let event = ActivityEvent(
            domain: item.type == .habit ? .habit : .task,
            entityId: item.id,
            timestampUTC: Date(),
            status: isGoalMetNow && !wasGoalMetBefore ? .completed : .started,
            value: amount
        )
        context.insert(event)
        
        // Award points if goal is now met (first time today)
        if isGoalMetNow && !wasGoalMetBefore {
            if item.type == .habit {
                let streak = calculateStreak(for: item)
                pointsService.habitCompleted(
                    habitId: item.id,
                    habitName: item.title,
                    streakDays: streak
                )
                postHabitGoalReached(item)
            }
        }
        
        item.updatedAt = Date()
        try? context.save()
        return amount
    }

    private func defaultIncrement(for item: PlanItem) -> Double {
        let unit = item.goalUnit.lowercased()
        if unit == "ml" { return 250 }
        if unit == "oz" { return 8 }
        if unit.contains("step") { return Double(settings.habitQuickAddStepsIncrement) }
        if unit == "m" || unit == "meter" || unit == "meters" { return preferredDistanceIncrementInKilometers() * 1000.0 }
        if unit == "km" || unit.contains("kilometer") || unit.contains("kilometre") {
            return preferredDistanceIncrementInKilometers()
        }
        if unit == "mi" || unit.contains("mile") {
            return preferredDistanceIncrementInKilometers() * 0.621371
        }
        // Time-based habits (min, minutes, hr, hours)
        if unit.contains("min") { return 5 }
        if unit.contains("hr") || unit.contains("hour") { return 0.25 } // 15 minutes
        return 1
    }

    private func preferredDistanceIncrementInKilometers() -> Double {
        let raw = max(0.1, settings.habitQuickAddDistanceIncrement)
        if settings.habitDistanceUnitSystem == .miles {
            return raw / 0.621371
        }
        return raw
    }

    func updateHabitValue(_ item: PlanItem, delta: Double, context: ModelContext) {
        let calendar = Calendar.current
        let wasGoalMetBefore = item.isGoalMet(on: Date())
        var appliedDelta: Double = 0

        if let existingLog = item.completionLogs.first(where: { calendar.isDateInToday($0.date) }) {
            if item.metricKind == .time {
                let current = Double(existingLog.durationSeconds ?? 0) / 60.0
                let newVal = max(0, current + delta)
                existingLog.durationSeconds = Int(newVal * 60)
                appliedDelta = newVal - current
            } else {
                let current = existingLog.value ?? 0
                let newVal = max(0, current + delta)
                existingLog.value = newVal
                appliedDelta = newVal - current
            }
            existingLog.completed = item.isGoalMet()
        } else if delta > 0 {
            let log = CompletionLog(date: Date(), completed: false)
            if item.metricKind == .time {
                log.durationSeconds = Int(max(0, delta) * 60)
            } else {
                log.value = max(0, delta)
            }
            item.completionLogs.append(log)
            log.completed = item.isGoalMet()
            appliedDelta = max(0, delta)
        }

        guard appliedDelta != 0 else { return }

        let isGoalMetNow = item.isGoalMet(on: Date())
        let status: ActivityStatus = {
            if isGoalMetNow && !wasGoalMetBefore { return .completed }
            if appliedDelta < 0 && wasGoalMetBefore && !isGoalMetNow { return .interrupted }
            return .started
        }()

        context.insert(
            ActivityEvent(
                domain: item.type == .habit ? .habit : .task,
                entityId: item.id,
                timestampUTC: Date(),
                status: status,
                value: appliedDelta
            )
        )

        if item.type == .habit && isGoalMetNow && !wasGoalMetBefore {
            let streak = calculateStreak(for: item)
            pointsService.habitCompleted(
                habitId: item.id,
                habitName: item.title,
                streakDays: streak
            )
            postHabitGoalReached(item)
        }

        item.updatedAt = Date()
        try? context.save()
    }

    private func didCompleteBeforeDeadline(_ item: PlanItem, at completionDate: Date) -> Bool {
        guard let dueDate = item.scheduledDate else { return false }
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: dueDate)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: item.scheduledTime ?? dueDate)
        var mergedComponents = DateComponents()
        mergedComponents.year = dateComponents.year
        mergedComponents.month = dateComponents.month
        mergedComponents.day = dateComponents.day
        mergedComponents.hour = timeComponents.hour ?? 23
        mergedComponents.minute = timeComponents.minute ?? 59
        mergedComponents.second = timeComponents.second ?? 59

        guard let deadline = calendar.date(from: mergedComponents) else {
            return completionDate <= dueDate
        }
        return completionDate <= deadline
    }
    
    // MARK: - Streak Calculation
    
    /// Calculates the current consecutive-day streak for a habit.
    /// Counts backwards from today, checking each day for a completed log.
    func calculateStreak(for item: PlanItem) -> Int {
        let calendar = Calendar.current
        var streak = 0
        var checkDate = Date()
        
        // Check up to 365 days back
        for _ in 0..<365 {
            let hasCompletion = item.completionLogs.contains { log in
                calendar.isDate(log.date, inSameDayAs: checkDate) && log.completed
            }
            
            if hasCompletion {
                streak += 1
            } else if streak > 0 {
                // Streak broken
                break
            } else {
                // No completion today yet (could be checking today before completion)
                // Only break if we're past today
                if !calendar.isDateInToday(checkDate) {
                    break
                }
            }
            
            guard let prevDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prevDay
        }
        
        return streak
    }
    
    // Navigation
    func nextDay() {
        selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
    }
    
    func prevDay() {
        selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
    }
    
    func setToday() {
        selectedDate = Date()
    }
    
    // MARK: - HealthKit Sync
    @MainActor
    func syncHealthData(from items: [PlanItem]? = nil) async {
        guard let context = modelContext else { return }
        guard HealthKitManager.shared.isHealthDataAvailable else {
            return
        }
        let sourceItems = items ?? allItems
        if let items {
            allItems = items
        }

        // Find habits with health tracking enabled
        let healthHabits = sourceItems.filter { $0.type == .habit }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let historyDays = 180

        for habit in healthHabits {
            guard let trackingType = inferredTrackingType(for: habit) else { continue }
            guard isAuthorizedForTracking(trackingType, habit: habit) else { continue }

            // Backfill HealthKit values so heatmap/charts for walking/running/etc. are populated.
            for offset in 0..<historyDays {
                guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
                let fetchedValue = await fetchHealthValue(for: habit, trackingType: trackingType, date: date)
                updateHabitLog(habit, value: fetchedValue, for: date, context: context)
            }
        }

        try? context.save()
    }

    private func fetchHealthValue(for habit: PlanItem, trackingType: String, date: Date) async -> Double {
        switch trackingType {
        case "steps":
            return await HealthKitManager.shared.fetchSteps(for: date)
        case "distance":
            let meters = await HealthKitManager.shared.fetchDistance(for: date)
            return convertDistance(meters, to: habit.goalUnit)
        case "running":
            if habit.goalUnit.lowercased().contains("step") {
                return await HealthKitManager.shared.fetchSteps(for: date)
            }
            let meters = await HealthKitManager.shared.fetchDistance(for: date)
            return convertDistance(meters, to: habit.goalUnit)
        case "cycling":
            let meters = await HealthKitManager.shared.fetchCyclingDistance(for: date)
            return convertDistance(meters, to: habit.goalUnit)
        case "sleep":
            let seconds = await HealthKitManager.shared.fetchSleep(for: date)
            if ["hr", "hours", "h"].contains(habit.goalUnit.lowercased()) {
                return seconds / 3600.0
            }
            return seconds / 60.0
        case "standing":
            let minutes = await HealthKitManager.shared.fetchStandMinutes(for: date)
            if ["hr", "hours", "h"].contains(habit.goalUnit.lowercased()) {
                return minutes / 60.0
            }
            return minutes
        case "mindfulness":
            let seconds = await HealthKitManager.shared.fetchMindfulMinutes(for: date)
            return seconds / 60.0
        default:
            return 0
        }
    }

    private func isAuthorizedForTracking(_ trackingType: String, habit: PlanItem) -> Bool {
        switch trackingType {
        case "steps":
            return HealthKitManager.shared.isAuthorized(for: "steps")
        case "distance":
            return HealthKitManager.shared.isAuthorized(for: "distance")
        case "running":
            if habit.goalUnit.lowercased().contains("step") {
                return HealthKitManager.shared.isAuthorized(for: "steps")
            }
            return HealthKitManager.shared.isAuthorized(for: "distance")
        case "cycling":
            return HealthKitManager.shared.isAuthorized(for: "cycling")
        case "sleep":
            return HealthKitManager.shared.isAuthorized(for: "sleep")
        case "standing":
            return HealthKitManager.shared.isAuthorized(for: "standing")
        case "mindfulness":
            return HealthKitManager.shared.isAuthorized(for: "mindfulness")
        default:
            return false
        }
    }

    private func inferredTrackingType(for item: PlanItem) -> String? {
        if let explicit = item.autoHealthTracking, !explicit.isEmpty {
            return explicit
        }

        guard item.type == .habit else { return nil }
        let title = item.title.lowercased()
        let unit = item.goalUnit.lowercased()

        if unit.contains("step") {
            if title.contains("run") || title.contains("jog") || title.contains("marathon") || title.contains("sprint") {
                return "running"
            }
            return "steps"
        }

        let distanceUnits = ["km", "mi", "m", "meter", "metre", "mile", "kilometer", "kilometre"]
        let isDistance = distanceUnits.contains { unit.hasPrefix($0) || unit == "\($0)s" }
        if isDistance {
            if title.contains("cycle") || title.contains("bike") || title.contains("ride") || title.contains("spin") {
                return "cycling"
            }
            if title.contains("run") || title.contains("jog") || title.contains("marathon") || title.contains("sprint") {
                return "running"
            }
            return "distance"
        }

        if (unit.contains("hour") || unit == "h" || unit == "hr"), (title.contains("sleep") || title.contains("nap")) {
            return "sleep"
        }

        if (unit.contains("min") || unit == "m"), (title.contains("meditat") || title.contains("mindful") || title.contains("breath")) {
            return "mindfulness"
        }

        return nil
    }

    private func convertDistance(_ meters: Double, to unit: String) -> Double {
        let u = unit.lowercased()
        if u.contains("km") || u.contains("kilometer") {
            return meters / 1000.0
        } else if u.contains("mi") || u.contains("mile") {
            return meters * 0.000621371
        } else {
            return meters // Default m
        }
    }
    
    private func updateHabitLog(_ item: PlanItem, value: Double, for date: Date, context: ModelContext) {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        let existingLog = item.completionLogs.first(where: { calendar.isDate($0.date, inSameDayAs: targetDay) })
        
        if let existingLog = existingLog {
             // Smart Update: Only update if new value is higher (preserves manual entries)
             if value > (existingLog.value ?? 0) {
                 existingLog.value = value
                 existingLog.completed = item.isGoalMet(on: targetDay)
                 item.updatedAt = Date()
             }
        } else if value > 0 {
            let log = CompletionLog(date: targetDay, completed: false)
            log.value = value
            item.completionLogs.append(log)
            log.completed = item.isGoalMet(on: targetDay)
            item.updatedAt = Date()
        }
    }
    
    // Calculate overall rate for today (completed habits / total habits)
    func calculateOverallRate(habits: [PlanItem]) -> Double {
        guard !habits.isEmpty else { return 0 }
        let completedCount = habits.filter { isCompleted($0, on: selectedDate) }.count
        return Double(completedCount) / Double(habits.count)
    }
    
    // Calculate monthly rate (average completion rate for the month)
    func calculateMonthlyRate(habits: [PlanItem]) -> Double {
        guard !habits.isEmpty else { return 0 }
        
        let calendar = Calendar.current
        let month = calendar.component(.month, from: selectedDate)
        let year = calendar.component(.year, from: selectedDate)
        
        // Get all days in the current month up to today
        guard let monthStart = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else { return 0 }
        let today = Date()
        let daysInMonth = calendar.range(of: .day, in: .month, for: selectedDate)?.count ?? 30
        let currentDay = calendar.component(.day, from: today)
        
        // Only count days up to today if we're in the current month
        let daysToCount = calendar.isDate(selectedDate, equalTo: today, toGranularity: .month) ? currentDay : daysInMonth
        
        var totalCompletions = 0
        var totalPossible = 0
        
        for day in 1...daysToCount {
            guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else { continue }
            if date > today { break }
            
            for habit in habits {
                totalPossible += 1
                if isCompleted(habit, on: date) {
                    totalCompletions += 1
                }
            }
        }
        
        guard totalPossible > 0 else { return 0 }
        return Double(totalCompletions) / Double(totalPossible)
    }

    private func postHabitGoalReached(_ item: PlanItem) {
        NotificationCenter.default.post(
            name: Self.habitGoalReachedNotification,
            object: nil,
            userInfo: [
                "habitId": item.id.uuidString,
                "habitTitle": item.title
            ]
        )
    }
}
