import Foundation
@testable import alarmo

struct MockClock: Clock {
    var now: Date
}
