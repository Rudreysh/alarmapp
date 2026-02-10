import Foundation
import SwiftData
import SwiftUI
import Combine

class PlanViewModel: ObservableObject {
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
        
        let result = allItems.filter { item in
            // Filter out subtasks
            if item.parentTask != nil { return false }
            
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
        print("[PlanFilter] selectedDate=\(selectedDate) input=\(allItems.count) output=\(result.count)")
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
            // Log skip or fail? Toggled off usually means reverting success. 
            // Better to remove previous event or log a new state.
            // Requirement says: "When a habit is marked done / value entered -> write success"
            // For now, let's just insert a "success" when toggled on.
        } else {
            // Toggle on
            let newLog = CompletionLog(date: selectedDate, completed: true)
            item.completionLogs.append(newLog)
            
            let event = ActivityEvent(
                domain: item.type == .habit ? .habit : .task,
                entityId: item.id,
                timestampUTC: Date(),
                status: .success
            )
            context.insert(event)
        }
        
        item.updatedAt = Date()
        try? context.save()
    }

    func quickIncrement(_ item: PlanItem, context: ModelContext) -> Double {
        let calendar = Calendar.current
        let increment: Double = {
            let unit = item.goalUnit.lowercased()
            if unit == "ml" { return 250 }
            if unit == "oz" { return 8 }
            if unit == "steps" { return 1000 }
            // Time-based habits (min, minutes, hr, hours)
            if unit.contains("min") { return 5 }
            if unit.contains("hr") || unit.contains("hour") { return 0.25 } // 15 minutes
            return 1
        }()

        if let existingLog = item.completionLogs.first(where: { calendar.isDateInToday($0.date) }) {
            if item.metricKind == .time {
                // For time-based habits, store in seconds
                existingLog.durationSeconds = (existingLog.durationSeconds ?? 0) + Int(increment * 60)
            } else {
                existingLog.value = (existingLog.value ?? 0) + increment
            }
            existingLog.completed = item.isGoalMet()
        } else {
            let log = CompletionLog(date: Date(), completed: false)
            if item.metricKind == .time {
                log.durationSeconds = Int(increment * 60)
            } else {
                log.value = increment
            }
            item.completionLogs.append(log)
            log.completed = item.isGoalMet()
        }
        
        let event = ActivityEvent(
            domain: item.type == .habit ? .habit : .task,
            entityId: item.id,
            timestampUTC: Date(),
            status: .success,
            value: increment
        )
        context.insert(event)
        
        item.updatedAt = Date()
        try? context.save()
        return increment
    }

    func incrementHabit(_ item: PlanItem, value: Double? = nil, context: ModelContext) -> Double {
        let calendar = Calendar.current
        let amount: Double = {
            if let v = value, v > 0 { return v }
            let unit = item.goalUnit.lowercased()
            if unit == "ml" { return 250 }
            if unit == "oz" { return 8 }
            if unit == "steps" { return 1000 }
            // Time-based habits (min, minutes, hr, hours)
            if unit.contains("min") { return 5 }
            if unit.contains("hr") || unit.contains("hour") { return 0.25 } // 15 minutes
            return 1
        }()

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

        let event = ActivityEvent(
            domain: item.type == .habit ? .habit : .task,
            entityId: item.id,
            timestampUTC: Date(),
            status: .success,
            value: amount
        )
        context.insert(event)
        
        item.updatedAt = Date()
        try? context.save()
        return amount
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
    // MARK: - HealthKit Sync
    @MainActor
    func syncHealthData() async {
        guard let context = modelContext else { return }
        
        // Find habits with health tracking enabled
        let healthHabits = allItems.filter { $0.type == .habit && $0.autoHealthTracking != nil }
        
        for habit in healthHabits {
            guard let trackingType = habit.autoHealthTracking else { continue }
            
            var fetchedValue: Double = 0.0
            
            if trackingType == "steps" {
                fetchedValue = await HealthKitManager.shared.fetchSteps(for: Date())
            } else if trackingType == "distance" {
                let meters = await HealthKitManager.shared.fetchDistance(for: Date())
                fetchedValue = convertDistance(meters, to: habit.goalUnit)
            } else if trackingType == "running" {
                if habit.goalUnit.lowercased() == "steps" {
                    fetchedValue = await HealthKitManager.shared.fetchSteps(for: Date())
                } else {
                    let meters = await HealthKitManager.shared.fetchDistance(for: Date())
                    fetchedValue = convertDistance(meters, to: habit.goalUnit)
                }
            } else if trackingType == "cycling" {
                let meters = await HealthKitManager.shared.fetchCyclingDistance(for: Date())
                fetchedValue = convertDistance(meters, to: habit.goalUnit)
            } else if trackingType == "sleep" {
                let seconds = await HealthKitManager.shared.fetchSleep(for: Date())
                // Convert seconds to hours if unit is hours
                if ["hr", "hours", "h"].contains(habit.goalUnit.lowercased()) {
                    fetchedValue = seconds / 3600.0
                } else {
                    fetchedValue = seconds / 60.0 // Default min
                }
            } else if trackingType == "standing" {
                let minutes = await HealthKitManager.shared.fetchStandMinutes(for: Date())
                if ["hr", "hours", "h"].contains(habit.goalUnit.lowercased()) {
                    fetchedValue = minutes / 60.0
                } else {
                    fetchedValue = minutes
                }
            } else if trackingType == "mindfulness" {
                let seconds = await HealthKitManager.shared.fetchMindfulMinutes(for: Date())
                // Convert to minutes
                fetchedValue = seconds / 60.0
            }
            
            updateHabitLog(habit, value: fetchedValue, context: context)
        }
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
    
    private func updateHabitLog(_ item: PlanItem, value: Double, context: ModelContext) {
        let calendar = Calendar.current
        if !calendar.isDateInToday(Date()) { return }
        
        let existingLog = item.completionLogs.first(where: { calendar.isDateInToday($0.date) })
        
        if let existingLog = existingLog {
             // Smart Update: Only update if new value is higher (preserves manual entries)
             if value > (existingLog.value ?? 0) {
                 existingLog.value = value
                 existingLog.completed = item.isGoalMet()
                 item.updatedAt = Date()
             }
        } else if value > 0 {
            let log = CompletionLog(date: Date(), completed: false)
            log.value = value
            item.completionLogs.append(log)
            log.completed = item.isGoalMet()
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
}
