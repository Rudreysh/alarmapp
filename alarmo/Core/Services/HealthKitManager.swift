import Foundation
import HealthKit
import Combine

@MainActor
class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()

    private let healthStore = HKHealthStore()
    private var observerQueries: [HKObserverQuery] = []

    /// Sets up HKObserverQuery instances so the app is notified whenever HealthKit data
    /// changes (e.g. steps accumulating in real-time or syncing from Watch).
    /// Call this after authorization is granted and re-call whenever authorization is refreshed.
    func startObservingHealthData(onUpdate: @escaping () -> Void) {
        guard isHealthDataAvailable else { return }
        // Stop any existing observer queries before re-registering
        for q in observerQueries { healthStore.stop(q) }
        observerQueries.removeAll()

        let sampleTypes: [HKSampleType] = [
            HKQuantityType.quantityType(forIdentifier: .stepCount),
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning),
            HKQuantityType.quantityType(forIdentifier: .distanceCycling),
            HKQuantityType.quantityType(forIdentifier: .appleStandTime),
            HKQuantityType.quantityType(forIdentifier: .dietaryWater),
            HKCategoryType.categoryType(forIdentifier: .sleepAnalysis),
            HKCategoryType.categoryType(forIdentifier: .mindfulSession),
        ].compactMap { $0 }

        for sampleType in sampleTypes {
            let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { _, completionHandler, error in
                guard error == nil else { completionHandler(); return }
                onUpdate()
                completionHandler()
            }
            healthStore.execute(query)
            observerQueries.append(query)

            // Background delivery lets the app receive updates even when not in foreground
            healthStore.enableBackgroundDelivery(for: sampleType, frequency: .immediate) { _, _ in }
        }
    }
    
    // Check if HealthKit is available on this device
    var isHealthDataAvailable: Bool {
        return HKHealthStore.isHealthDataAvailable()
    }
    
    // Request Authorization
    func requestAuthorization(for category: String? = nil) async -> Bool {
        if let category {
            return await requestAuthorization(for: [category])
        }
        return await requestAuthorization(for: nil as [String]?)
    }

    // Request Authorization for multiple categories
    func requestAuthorization(for categories: [String]) async -> Bool {
        await requestAuthorization(for: Optional(categories))
    }

    private func requestAuthorization(for categories: [String]?) async -> Bool {
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

        func addTypes(for normalizedCategory: String) {
            switch normalizedCategory {
            case "activity":
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
            case "water", "hydration":
                addReadQuantity(.dietaryWater)
            default:
                break
            }
        }

        if let categories, !categories.isEmpty {
            for category in categories {
                addTypes(for: category.lowercased())
            }
        } else {
            // Default onboarding/read scope for current health-backed habits.
            addTypes(for: "activity")
            addTypes(for: "cycling")
            addTypes(for: "sleep")
            addTypes(for: "standing")
            addTypes(for: "mindfulness")
            addTypes(for: "water")
        }

        guard !readTypes.isEmpty else { return true }

        do {
            // Read-only authorization is enough for Alarmo onboarding and avoids
            // write-capability mismatches that can destabilize certain health types.
            try await healthStore.requestAuthorization(toShare: [], read: readTypes)
            
            // Mark each requested category so isAuthorized() can pass for read-only checks.
            if let categories, !categories.isEmpty {
                for cat in categories {
                    UserDefaults.standard.set(true, forKey: "hk_requested_\(cat.lowercased())")
                }
            } else {
                let allCats = ["activity", "steps", "distance", "cycling", "running", "sleep", "standing", "mindfulness", "water"]
                for cat in allCats {
                    UserDefaults.standard.set(true, forKey: "hk_requested_\(cat)")
                }
            }
            return true
        } catch {
            print("HealthKit Authorization Failed: \(error.localizedDescription)")
            return false
        }
    }
    
    // Check Authorization Status
    // For read-only types HealthKit deliberately hides the read-authorization status
    // (authorizationStatus always returns .notDetermined). We treat any category for
    // which requestAuthorization was successfully called as "authorized" — if the user
    // denied access, HealthKit queries simply return no data.
    func isAuthorized(for category: String) -> Bool {
        guard isHealthDataAvailable else {
            print("[HealthKitManager] isAuthorized: HealthData NOT available")
            return false
        }

        let normalizedKey = category.lowercased()

        // Primary check: was authorization ever requested for this category?
        let wasRequested = UserDefaults.standard.bool(forKey: "hk_requested_\(normalizedKey)")

        // Fallback: infer from the HealthKit sharing-status (works for write-capable types).
        let type: HKObjectType?
        switch normalizedKey {
        case "activity", "steps":
            type = HKObjectType.quantityType(forIdentifier: .stepCount)
        case "distance", "running":
            type = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)
        case "cycling":
            type = HKObjectType.quantityType(forIdentifier: .distanceCycling)
        case "sleep":
            type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)
        case "standing":
            type = HKObjectType.quantityType(forIdentifier: .appleStandTime)
        case "mindfulness":
            type = HKCategoryType.categoryType(forIdentifier: .mindfulSession)
        case "water", "hydration":
            type = HKObjectType.quantityType(forIdentifier: .dietaryWater)
        default:
            return false
        }

        guard let t = type else { return wasRequested }

        let status = healthStore.authorizationStatus(for: t)
        // .sharingAuthorized → user granted write (uncommon here since we only request read).
        // .notDetermined    → read-only: authorization state hidden by iOS for privacy.
        // .sharingDenied    → user explicitly denied write access; still allow read attempt.
        let statusAllows = status == .sharingAuthorized || status == .notDetermined
        let isAuth = wasRequested || statusAllows
        print("[HealthKitManager] isAuthorized for \(category): \(isAuth) (requested: \(wasRequested), status: \(status.rawValue))")
        return isAuth
    }
    
    // Fetch Steps for a specific date (usually today)
    func fetchSteps(for date: Date) async -> Double {
        guard canQueryHealthData else { return 0 }
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let result = await fetchSum(for: stepType, date: date, unit: .count())
        print("[HealthKitManager] fetchSteps for \(date): \(result)")
        return result
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

    // Fetch Water Intake in milliliters
    func fetchWaterIntake(for date: Date) async -> Double {
        guard canQueryHealthData else { return 0 }
        let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater)!
        let liters = await fetchSum(for: waterType, date: date, unit: .liter())
        return liters * 1000.0
    }
    
    // Generic Sum Query for Quantities
    private func fetchSum(for type: HKQuantityType, date: Date, unit: HKUnit) async -> Double {
        guard canQueryHealthData else { return 0 }
        print("[HealthKitManager] fetchSum called for \(type.identifier) at \(date)")
        return await withCheckedContinuation { continuation in
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            
            print("[HealthKitManager] Querying from \(startOfDay) to \(endOfDay)")
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
            
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error = error {
                    print("[HealthKitManager] Query error: \(error.localizedDescription)")
                    continuation.resume(returning: 0.0)
                    return
                }
                guard let result = result, let sum = result.sumQuantity() else {
                    print("[HealthKitManager] No sum quantity returned")
                    continuation.resume(returning: 0.0)
                    return
                }
                let value = sum.doubleValue(for: unit)
                print("[HealthKitManager] Query returned: \(value)")
                continuation.resume(returning: value)
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
        let available = isHealthDataAvailable
        print("[HealthKitManager] canQueryHealthData: \(available)")
        return available
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
