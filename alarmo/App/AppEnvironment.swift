import Foundation

struct AppEnvironment {
    let clock: Clock
    let uuidProvider: UUIDProviding
    let userSettingsRepository: UserSettingsRepository
}
