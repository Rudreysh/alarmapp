import Foundation
import HealthKit
import Combine

@MainActor
class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    
    private let healthStore = HKHealthStore()
    
    // Check if HealthKit is available on this device
    var isHealthDataAvailable: Bool {
        return HKHealthStore.isHealthDataAvailable()
    }
    
    // Request Authorization
    func requestAuthorization(for category: String? = nil) async -> Bool {
        guard isHealthDataAvailable else { return false }
        guard EntitlementInspector.hasHealthKitAccess else { return false }

        var readTypes: Set<HKObjectType> = []

        func addReadQuantity(_ identifier: HKQuantityTypeIdentifier) {
            if let type = HKObjectType.quantityType(forIdentifier: identifier) {
                readTypes.insert(type)
            }
        }

        func addReadCategory(_ identifier: HKCategoryTypeIdentifier) {
            if let type = HKCategoryType.categoryType(forIdentifier: identifier) {
                readTypes.insert(type)
            }
        }

        if let category = category {
            switch category {
            case "activity":
                // Keep onboarding request minimal/read-only to avoid unsupported write prompts.
                addReadQuantity(.stepCount)
                addReadQuantity(.distanceWalkingRunning)
            case "steps":
                addReadQuantity(.stepCount)
            case "distance":
                addReadQuantity(.distanceWalkingRunning)
            case "cycling":
                addReadQuantity(.distanceCycling)
            case "running":
                addReadQuantity(.stepCount)
                addReadQuantity(.distanceWalkingRunning)
            case "sleep":
                addReadCategory(.sleepAnalysis)
            case "standing":
                addReadQuantity(.appleStandTime)
            case "mindfulness":
                addReadCategory(.mindfulSession)
            default:
                break
            }
        } else {
            addReadQuantity(.stepCount)
            addReadQuantity(.distanceWalkingRunning)
            addReadQuantity(.distanceCycling)
            addReadCategory(.sleepAnalysis)
            addReadQuantity(.appleStandTime)
            addReadCategory(.mindfulSession)
        }

        guard !readTypes.isEmpty else { return true }

        do {
            // Read-only authorization is enough for Alarmo onboarding and avoids
            // write-capability mismatches that can destabilize certain health types.
            try await healthStore.requestAuthorization(toShare: [], read: readTypes)
            return true
        } catch {
            print("HealthKit Authorization Failed: \(error.localizedDescription)")
            return false
        }
    }
    
    // Check Authorization Status
    func isAuthorized(for category: String) -> Bool {
        guard isHealthDataAvailable else { return false }
        
        let type: HKObjectType?
        switch category {
        case "activity":
            type = HKObjectType.quantityType(forIdentifier: .stepCount)
        case "steps":
            type = HKObjectType.quantityType(forIdentifier: .stepCount)
        case "distance", "running", "cycling":
             // Running/Cycling use Distance as primary check
             if category == "cycling" {
                 type = HKObjectType.quantityType(forIdentifier: .distanceCycling)
             } else {
                 type = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)
             }
        case "sleep":
             type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)
        case "standing":
             type = HKObjectType.quantityType(forIdentifier: .appleStandTime)
        case "mindfulness":
             type = HKCategoryType.categoryType(forIdentifier: .mindfulSession)
        default:
            return false
        }
        
        guard let t = type else { return false }
        return healthStore.authorizationStatus(for: t) == .sharingAuthorized
    }
    
    // Fetch Steps for a specific date (usually today)
    func fetchSteps(for date: Date) async -> Double {
        guard canQueryHealthData else { return 0 }
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        return await fetchSum(for: stepType, date: date, unit: .count())
    }
    
    // Fetch Walking/Running Distance in Meters
    func fetchDistance(for date: Date) async -> Double {
        guard canQueryHealthData else { return 0 }
        let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
        return await fetchSum(for: distanceType, date: date, unit: .meter())
    }
    
    // Fetch Cycling Distance in Meters
    func fetchCyclingDistance(for date: Date) async -> Double {
        guard canQueryHealthData else { return 0 }
        let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceCycling)!
        return await fetchSum(for: distanceType, date: date, unit: .meter())
    }
    
    // Fetch Stand Time in Minutes
    func fetchStandMinutes(for date: Date) async -> Double {
        guard canQueryHealthData else { return 0 }
        let type = HKQuantityType.quantityType(forIdentifier: .appleStandTime)!
        return await fetchSum(for: type, date: date, unit: .minute())
    }
    
    // Fetch Sleep in Hours
    func fetchSleep(for date: Date) async -> Double {
        guard canQueryHealthData else { return 0 }
        return await withCheckedContinuation { continuation in
            let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
            let startOfDay = Calendar.current.startOfDay(for: date)
            let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

            // Keep overlapping intervals too, because sleep commonly starts before midnight.
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: [])
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, _ in
                guard let categorySamples = samples as? [HKCategorySample], !categorySamples.isEmpty else {
                    continuation.resume(returning: 0)
                    return
                }

                let asleepSamples = categorySamples.filter { self.isAsleepSampleValue($0.value) }
                let effectiveSamples = asleepSamples.isEmpty
                    ? categorySamples.filter { $0.value == HKCategoryValueSleepAnalysis.inBed.rawValue }
                    : asleepSamples

                let intervals = effectiveSamples.compactMap { sample -> DateInterval? in
                    let clippedStart = max(sample.startDate, startOfDay)
                    let clippedEnd = min(sample.endDate, endOfDay)
                    guard clippedEnd > clippedStart else { return nil }
                    return DateInterval(start: clippedStart, end: clippedEnd)
                }

                let totalSeconds = self.mergedDuration(of: intervals)
                continuation.resume(returning: totalSeconds)
            }

            healthStore.execute(query)
        }
    }
    
    // Fetch Mindful Minutes
    func fetchMindfulMinutes(for date: Date) async -> Double {
        guard canQueryHealthData else { return 0 }
        let mindfulType = HKCategoryType.categoryType(forIdentifier: .mindfulSession)!
        return await fetchTime(for: mindfulType, date: date)
    }
    
    // Generic Sum Query for Quantities
    private func fetchSum(for type: HKQuantityType, date: Date, unit: HKUnit) async -> Double {
        guard canQueryHealthData else { return 0 }
        return await withCheckedContinuation { continuation in
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
            
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                guard let result = result, let sum = result.sumQuantity() else {
                    continuation.resume(returning: 0.0)
                    return
                }
                continuation.resume(returning: sum.doubleValue(for: unit))
            }
            
            healthStore.execute(query)
        }
    }
    
    // Generic Query for Categories (Time based: Sleep, Mindfulness)
    private func fetchTime(for type: HKCategoryType, date: Date) async -> Double {
        guard canQueryHealthData else { return 0 }
        return await withCheckedContinuation { continuation in
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
            
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                guard let samples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: 0.0)
                    return
                }
                
                // Calculate total duration
                let totalSeconds = samples.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                
                // Return in Hours for Sleep, Minutes for Mindfulness?
                // Standardize on Hours for now, convert in VM. Or Minutes?
                // Let's perform conversion in VM. Return Seconds.
                continuation.resume(returning: totalSeconds)
            }
            
            healthStore.execute(query)
        }
    }

    private var canQueryHealthData: Bool {
        isHealthDataAvailable
    }

    nonisolated private func isAsleepSampleValue(_ value: Int) -> Bool {
        return value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
            || value == HKCategoryValueSleepAnalysis.asleepCore.rawValue
            || value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue
            || value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
    }

    nonisolated private func mergedDuration(of intervals: [DateInterval]) -> TimeInterval {
        guard !intervals.isEmpty else { return 0 }
        let sorted = intervals.sorted { $0.start < $1.start }

        var total: TimeInterval = 0
        var current = sorted[0]

        for interval in sorted.dropFirst() {
            if interval.start <= current.end {
                current = DateInterval(start: current.start, end: max(current.end, interval.end))
            } else {
                total += current.duration
                current = interval
            }
        }
        total += current.duration
        return total
    }
}
