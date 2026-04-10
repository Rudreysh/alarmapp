import Foundation
import Combine

#if canImport(FamilyControls)
import FamilyControls
#endif

@MainActor
final class ScreenTimeAuthorizationManager: ObservableObject {
    static let shared = ScreenTimeAuthorizationManager()

    enum AuthorizationState: Equatable {
        case unknown
        case approved
        case denied
        case notAvailable
    }

    @Published private(set) var state: AuthorizationState = .unknown
    @Published private(set) var statusMessage: String?
    private let simulatorMockAccessKey = "screenTime.simulatorMockAccessGranted"

    private init() {
        refreshStatus()
    }

    func refreshStatus() {
        #if targetEnvironment(simulator)
        let granted = UserDefaults.standard.bool(forKey: simulatorMockAccessKey)
        state = granted ? .approved : .unknown
        statusMessage = granted
            ? "Simulator mock mode is active. App/category selections are simulated."
            : "Simulator mock mode: tap Enable Screen Time Access to test blocking flows."
        #elseif canImport(FamilyControls)
        guard EntitlementInspector.hasFamilyControlsAccess else {
            state = .notAvailable
            statusMessage = "Screen Time capability is missing in this build. Enable Family Controls entitlement."
            return
        }

        let status = AuthorizationCenter.shared.authorizationStatus
        switch status {
        case .approved:
            state = .approved
            statusMessage = nil
        case .denied:
            state = .denied
            statusMessage = "Screen Time permission is denied. Enable it in iOS Settings."
        case .notDetermined:
            state = .unknown
            statusMessage = nil
        @unknown default:
            state = .unknown
            statusMessage = nil
        }
        #else
        state = .notAvailable
        statusMessage = "Family Controls is not available on this build."
        #endif
    }

    func requestAuthorization() async {
        #if targetEnvironment(simulator)
        UserDefaults.standard.set(true, forKey: simulatorMockAccessKey)
        state = .approved
        statusMessage = "Simulator mock mode is active. App/category selections are simulated."
        #elseif canImport(FamilyControls)
        guard EntitlementInspector.hasFamilyControlsAccess else {
            state = .notAvailable
            statusMessage = "Screen Time capability is missing in this build. Enable Family Controls entitlement."
            return
        }

        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            statusMessage = nil
        } catch {
            print("[ScreenTimeAuthorizationManager] Authorization request failed: \(error)")
            let nsError = error as NSError
            if nsError.domain == NSCocoaErrorDomain && nsError.code == 4099 {
                state = .notAvailable
                statusMessage = "Could not connect to FamilyControlsAgent. Use a real device and ensure Family Controls entitlement is enabled."
                return
            } else {
                statusMessage = error.localizedDescription
            }
        }
        refreshStatus()
        #else
        state = .notAvailable
        statusMessage = "Family Controls is not available on this build."
        #endif
    }

    var isAuthorized: Bool {
        state == .approved
    }

    #if targetEnvironment(simulator)
    func resetSimulatorMockAuthorization() {
        UserDefaults.standard.set(false, forKey: simulatorMockAccessKey)
        refreshStatus()
    }
    #endif
}
