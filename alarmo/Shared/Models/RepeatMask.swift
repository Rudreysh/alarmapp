import Foundation

enum RepeatMask {
    static let sunday = 1 << 0
    static let monday = 1 << 1
    static let tuesday = 1 << 2
    static let wednesday = 1 << 3
    static let thursday = 1 << 4
    static let friday = 1 << 5
    static let saturday = 1 << 6

    static let allDays = sunday | monday | tuesday | wednesday | thursday | friday | saturday
    static let monToSat = monday | tuesday | wednesday | thursday | friday | saturday

    static func mask(from weekdays: [Int]) -> Int {
        weekdays.reduce(0) { $0 | (1 << ($1 - 1)) }
    }

    static func weekdays(from mask: Int) -> [Int] {
        (1...7).filter { (mask & (1 << ($0 - 1))) != 0 }
    }

    static func isEnabled(_ mask: Int, weekdayIndex: Int) -> Bool {
        let bit = 1 << weekdayIndex
        return (mask & bit) != 0
    }
}
