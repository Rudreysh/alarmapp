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
        
        var readTypes: Set<HKObjectType> = []
        var shareTypes: Set<HKSampleType> = []
        
        if let category = category {
            switch category {
            case "steps":
                let t1 = HKObjectType.quantityType(forIdentifier: .stepCount)!
                let t2 = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
                readTypes.insert(t1); shareTypes.insert(t1)
                readTypes.insert(t2); shareTypes.insert(t2)
            case "distance":
                 let t1 = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!
                 let t2 = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
                 readTypes.insert(t1); shareTypes.insert(t1)
                 readTypes.insert(t2); shareTypes.insert(t2)
            case "cycling":
                 let t1 = HKObjectType.quantityType(forIdentifier: .distanceCycling)!
                 let t2 = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
                 readTypes.insert(t1); shareTypes.insert(t1)
                 readTypes.insert(t2); shareTypes.insert(t2)
            case "running":
                // Running needs Steps, Distance, and Calories
                let t1 = HKObjectType.quantityType(forIdentifier: .stepCount)!
                let t2 = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!
                let t3 = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
                readTypes.insert(t1); shareTypes.insert(t1)
                readTypes.insert(t2); shareTypes.insert(t2)
                readTypes.insert(t3); shareTypes.insert(t3)
            case "sleep":
                 let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
                 readTypes.insert(type)
                 shareTypes.insert(type)
            case "standing":
                 let type = HKObjectType.quantityType(forIdentifier: .appleStandTime)!
                 readTypes.insert(type)
                 shareTypes.insert(type)
            case "mindfulness":
                 let type = HKCategoryType.categoryType(forIdentifier: .mindfulSession)!
                 readTypes.insert(type)
                 shareTypes.insert(type)
            default:
                break
            }
        } else {
             // Fallback: Request All (as SampleTypes)
             let allTypes: [HKSampleType] = [
                HKObjectType.quantityType(forIdentifier: .stepCount)!,
                HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
                HKObjectType.quantityType(forIdentifier: .distanceCycling)!,
                HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!,
                HKObjectType.quantityType(forIdentifier: .appleStandTime)!,
                HKCategoryType.categoryType(forIdentifier: .mindfulSession)!
             ]
             for t in allTypes {
                 readTypes.insert(t)
                 shareTypes.insert(t)
             }
        }
        
        guard !readTypes.isEmpty else { return true }
        
        do {
            try await healthStore.requestAuthorization(toShare: shareTypes, read: readTypes)
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
        let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
        return await fetchTime(for: sleepType, date: date)
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
}
