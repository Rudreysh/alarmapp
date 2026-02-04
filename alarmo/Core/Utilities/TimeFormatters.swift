import Foundation

enum TimeFormatters {
    static func padded(_ value: Int) -> String {
        String(format: "%02d", value)
    }

    static func formattedTime(hour: Int, minute: Int) -> String {
        "\(padded(hour)):\(padded(minute))"
    }

    static func formattedTimeWithSeconds(hour: Int, minute: Int, second: Int) -> String {
        "\(padded(hour)):\(padded(minute)):\(padded(second))"
    }

    static func formattedTime24Hour(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    static func formattedTime24HourWithSeconds(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    static func shortTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm aa"
        return formatter.string(from: date).lowercased()
    }

    static func shortTimeWithSeconds(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm:ss aa"
        return formatter.string(from: date).lowercased()
    }
}
