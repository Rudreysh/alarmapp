import Foundation
import Combine

// MARK: - Entitlements
protocol EntitlementProvider {
    var isPro: Bool { get }
}

class MockEntitlementProvider: EntitlementProvider {
    var isPro: Bool = false // Default to free for now, toggle here to test Pro
}

// MARK: - Config Store
@MainActor
class IntervalTimerConfigStore: ObservableObject {
    @Published var config: IntervalTimerConfig = IntervalTimerConfig()
    
    private let fileURL: URL
    
    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let domainDir = appSupport.appendingPathComponent(Bundle.main.bundleIdentifier ?? "com.alarmo.app", isDirectory: true)
        if !FileManager.default.fileExists(atPath: domainDir.path) {
            try? FileManager.default.createDirectory(at: domainDir, withIntermediateDirectories: true)
        }
        self.fileURL = domainDir.appendingPathComponent("interval_timer_config.json")
        load()
    }
    
    func save() {
        do {
            let data = try JSONEncoder().encode(config)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[IntervalTimerConfigStore] Save failed: \(error)")
        }
    }
    
    func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(IntervalTimerConfig.self, from: data) else {
            return
        }
        self.config = decoded
    }
    
    func update(_ newConfig: IntervalTimerConfig) {
        self.config = newConfig
        save()
    }
}

// MARK: - Event Store (Stub)
class PomodoroEventStore {
    static let shared = PomodoroEventStore()
    
    func record(event: PomodoroEvent) {
        // In a real app, append to JSON log or send to analytics
        print("📊 [PomodoroEvent] \(event.segment.rawValue) finished. Actual: \(event.actualSeconds)s")
    }
}
