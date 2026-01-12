import AppTrackingTransparency
import Foundation

enum TrackingStatus: Equatable {
    case notDetermined
    case restricted
    case denied
    case authorized
}

protocol TrackingPermissionService {
    func status() -> TrackingStatus
    func request() async -> TrackingStatus
}

struct SystemTrackingPermissionService: TrackingPermissionService {
    func status() -> TrackingStatus {
        let status = ATTrackingManager.trackingAuthorizationStatus
        return status.asTrackingStatus
    }

    func request() async -> TrackingStatus {
        let status = await ATTrackingManager.requestTrackingAuthorization()
        return status.asTrackingStatus
    }
}

private extension ATTrackingManager.AuthorizationStatus {
    var asTrackingStatus: TrackingStatus {
        switch self {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .authorized:
            return .authorized
        @unknown default:
            return .denied
        }
    }
}
