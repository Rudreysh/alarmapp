import Foundation
import Combine

final class TrackingExplainerViewModel: ObservableObject {
    @Published private(set) var status: TrackingStatus = .notDetermined

    private let service: TrackingPermissionService

    init(service: TrackingPermissionService = SystemTrackingPermissionService()) {
        self.service = service
        self.status = service.status()
    }

    @MainActor
    func handleNext() async -> TrackingStatus {
        let current = service.status()
        status = current
        if current == .notDetermined {
            let result = await service.request()
            status = result
            return result
        }
        return current
    }
}
