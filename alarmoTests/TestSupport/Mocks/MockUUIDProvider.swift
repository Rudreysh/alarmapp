import Foundation
@testable import alarmo

struct MockUUIDProvider: UUIDProviding {
    let value: UUID

    func make() -> UUID {
        value
    }
}
