import XCTest
@testable import alarmo

final class TrackingExplainerViewModelTests: XCTestCase {
    func test_notDetermined_requestsPermission() async {
        let service = MockTrackingPermissionService(status: .notDetermined, result: .authorized)
        let viewModel = TrackingExplainerViewModel(service: service)
        let result = await viewModel.handleNext()
        XCTAssertEqual(result, .authorized)
        XCTAssertTrue(service.requestCalled)
    }

    func test_alreadyDetermined_skipsRequest() async {
        let service = MockTrackingPermissionService(status: .denied, result: .authorized)
        let viewModel = TrackingExplainerViewModel(service: service)
        let result = await viewModel.handleNext()
        XCTAssertEqual(result, .denied)
        XCTAssertFalse(service.requestCalled)
    }
}

private final class MockTrackingPermissionService: TrackingPermissionService {
    var requestCalled = false
    let current: TrackingStatus
    let result: TrackingStatus

    init(status: TrackingStatus, result: TrackingStatus) {
        self.current = status
        self.result = result
    }

    func status() -> TrackingStatus { current }

    func request() async -> TrackingStatus {
        requestCalled = true
        return result
    }
}
