import SwiftUI
import SwiftData

@main
struct AwaykApp: App {
    @UIApplicationDelegateAdaptor(AlarmAppDelegate.self) private var appDelegate
    
    private var sharedModelContainer: ModelContainer = Self.buildModelContainer()

    private static func buildModelContainer() -> ModelContainer {
        let schema = Schema([PlanItem.self, CompletionLog.self, ActivityEvent.self, AppList.self])
        let config = ModelConfiguration(schema: schema)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            #if targetEnvironment(simulator)
            print("[SwiftData] Primary container load failed: \(error)")
            purgeDefaultStoreForSimulator()
            do {
                let rebuilt = try ModelContainer(for: schema, configurations: [config])
                print("[SwiftData] Rebuilt container after purging simulator store.")
                return rebuilt
            } catch {
                print("[SwiftData] Rebuild after purge failed: \(error)")
            }
            #endif

            // Safe fallback: keep app bootable even if the persisted store is corrupted.
            do {
                let inMemoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                print("[SwiftData] Falling back to in-memory container.")
                return try ModelContainer(for: schema, configurations: [inMemoryConfig])
            } catch {
                fatalError("Failed to create any SwiftData container (persistent + in-memory): \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
        .modelContainer(sharedModelContainer)
    }
}

#if targetEnvironment(simulator)
private func purgeDefaultStoreForSimulator() {
    let fm = FileManager.default
    guard let supportDir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
    let base = supportDir.appendingPathComponent("default.store")
    let candidates = [
        base,
        supportDir.appendingPathComponent("default.store-wal"),
        supportDir.appendingPathComponent("default.store-shm")
    ]
    
    for url in candidates where fm.fileExists(atPath: url.path) {
        do {
            try fm.removeItem(at: url)
            print("[SwiftData] Removed incompatible simulator store file: \(url.lastPathComponent)")
        } catch {
            print("[SwiftData] Failed removing \(url.lastPathComponent): \(error)")
        }
    }
}
#endif
