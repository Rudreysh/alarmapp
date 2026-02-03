import XCTest
import SwiftData
@testable import alarmo

final class HabitLogicTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: PlanItem.self, CompletionLog.self, configurations: config)
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    func testBuildSuccessBoundary() {
        let habit = PlanItem(title: "Build Habit", type: .habit)
        habit.habitIntent = .build
        habit.goalValue = 10.0
        habit.metricKind = .count
        context.insert(habit)
        
        // Log 1: 4
        let log1 = CompletionLog(date: Date(), completed: true)
        log1.value = 4.0
        habit.completionLogs.append(log1)
        
        // Log 2: 6
        let log2 = CompletionLog(date: Date(), completed: true)
        log2.value = 6.0
        habit.completionLogs.append(log2)
        
        XCTAssertTrue(habit.isSuccessful(on: Date()), "Build habit should be successful when >= goal")
    }
    
    func testBuildFailBoundary() {
        let habit = PlanItem(title: "Build Habit Fail", type: .habit)
        habit.habitIntent = .build
        habit.goalValue = 10.0
        habit.metricKind = .count
        context.insert(habit)
        
        // Log 1: 9.9
        let log1 = CompletionLog(date: Date(), completed: true)
        log1.value = 9.9
        habit.completionLogs.append(log1)
        
        XCTAssertFalse(habit.isSuccessful(on: Date()), "Build habit should fail when < goal")
    }

    func testQuitSuccessBoundary() {
        let habit = PlanItem(title: "Quit Habit", type: .habit)
        habit.habitIntent = .quit
        habit.goalValue = 5.0 // Allowable
        habit.metricKind = .quantity
        context.insert(habit)
        
        // Log 1: 2
        let log1 = CompletionLog(date: Date(), completed: true)
        log1.value = 2.0
        habit.completionLogs.append(log1)
        
        // Log 2: 3
        let log2 = CompletionLog(date: Date(), completed: true)
        log2.value = 3.0
        habit.completionLogs.append(log2)
        
        // Total 5 <= 5
        XCTAssertTrue(habit.isSuccessful(on: Date()), "Quit habit should be successful when <= allowable")
    }

    func testQuitFailBoundary() {
        let habit = PlanItem(title: "Quit Habit Fail", type: .habit)
        habit.habitIntent = .quit
        habit.goalValue = 5.0
        habit.metricKind = .quantity
        context.insert(habit)
        
        // Log 1: 5.1
        let log1 = CompletionLog(date: Date(), completed: true)
        log1.value = 5.1
        habit.completionLogs.append(log1) // Assuming "completed" log means user recorded entry
        
        XCTAssertFalse(habit.isSuccessful(on: Date()), "Quit habit should fail when > allowable")
    }
    
    func testTimeMetricLogic() {
        let habit = PlanItem(title: "Time Habit", type: .habit)
        habit.habitIntent = .build
        habit.goalValue = 60.0 // 60 minutes
        habit.metricKind = .time
        context.insert(habit)
        
        // Log 1: 30 min (1800 sec)
        let log1 = CompletionLog(date: Date(), completed: true)
        log1.durationSeconds = 1800
        habit.completionLogs.append(log1)
        
        XCTAssertFalse(habit.isSuccessful(on: Date()), "Should fail with only 30 mins")
        
        // Log 2: 30 min
        let log2 = CompletionLog(date: Date(), completed: true)
        log2.durationSeconds = 1800
        habit.completionLogs.append(log2)
        
        XCTAssertTrue(habit.isSuccessful(on: Date()), "Should succeed with 60 mins")
    }
    
    func testMigrationDefaults() {
        let habit = PlanItem(title: "Legacy", type: .habit)
        // Verify defaults
        XCTAssertEqual(habit.habitIntent, .build)
        XCTAssertEqual(habit.goalPeriod, .dayLong)
        XCTAssertEqual(habit.metricKind, .count)
    }
}
