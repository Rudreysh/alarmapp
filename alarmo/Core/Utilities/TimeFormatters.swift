import Foundation

enum TimeFormatters {
    static func padded(_ value: Int) -> String {
        String(format: "%02d", value)
    }

    static func formattedTime(hour: Int, minute: Int) -> String {
        "\(padded(hour)):\(padded(minute))"
    }

    static func formattedTime24Hour(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
