import Foundation

/// Represents a city added to the Overlap world clock.
struct OverlapCity: Identifiable, Codable, Equatable {
    var id: UUID
    var cityName: String
    var timeZoneIdentifier: String
    var abbreviation: String
    var isStarred: Bool
    var isMinimized: Bool  // shows as small row instead of card
    var notes: String
    var customLabel: String?
    var availabilityStart: Int  // minutes from midnight (e.g. 540 = 09:00)
    var availabilityEnd: Int    // minutes from midnight (e.g. 1020 = 17:00)
    var flexMinutesBefore: Int
    var flexMinutesAfter: Int
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        cityName: String,
        timeZoneIdentifier: String,
        abbreviation: String = "",
        isStarred: Bool = false,
        isMinimized: Bool = false,
        notes: String = "",
        customLabel: String? = nil,
        availabilityStart: Int = 540,
        availabilityEnd: Int = 1020,
        flexMinutesBefore: Int = 30,
        flexMinutesAfter: Int = 30,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.cityName = cityName
        self.timeZoneIdentifier = timeZoneIdentifier
        self.abbreviation = abbreviation.isEmpty
            ? (TimeZone(identifier: timeZoneIdentifier)?.abbreviation() ?? "")
            : abbreviation
        self.isStarred = isStarred
        self.isMinimized = isMinimized
        self.notes = notes
        self.customLabel = customLabel
        self.availabilityStart = availabilityStart
        self.availabilityEnd = availabilityEnd
        self.flexMinutesBefore = flexMinutesBefore
        self.flexMinutesAfter = flexMinutesAfter
        self.sortOrder = sortOrder
    }

    var displayName: String {
        customLabel ?? cityName
    }

    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? .current
    }

    /// Offset in hours from a reference time zone.
    func offsetHours(from reference: TimeZone, at date: Date = Date()) -> Double {
        let refOffset = Double(reference.secondsFromGMT(for: date))
        let cityOffset = Double(timeZone.secondsFromGMT(for: date))
        return (cityOffset - refOffset) / 3600.0
    }

    /// Returns formatted offset string like "+4.5", "-8", "+0"
    func offsetString(from reference: TimeZone, at date: Date = Date()) -> String {
        let hours = offsetHours(from: reference, at: date)
        if hours == 0 { return "+0" }
        if hours == hours.rounded() {
            return String(format: "%+.0f", hours)
        }
        return String(format: "%+.1f", hours)
    }
}

/// Major world cities database for search, with aliases for common names.
struct WorldCityDatabase {
    struct CityEntry: Identifiable {
        let id = UUID()
        let cityName: String
        let timeZoneIdentifier: String
        let country: String
        let aliases: [String]
    }

    /// Common city aliases that map to timezone identifiers
    private static let cityAliases: [(name: String, tz: String, country: String, aliases: [String])] = [
        ("Bengaluru", "Asia/Kolkata", "India", ["Bangalore", "Bengaluru"]),
        ("Mumbai", "Asia/Kolkata", "India", ["Bombay"]),
        ("Chennai", "Asia/Kolkata", "India", ["Madras"]),
        ("Delhi", "Asia/Kolkata", "India", ["New Delhi"]),
        ("Hyderabad", "Asia/Kolkata", "India", ["Hyderabad India"]),
        ("Pune", "Asia/Kolkata", "India", []),
        ("Ahmedabad", "Asia/Kolkata", "India", []),
        ("Jaipur", "Asia/Kolkata", "India", []),
        ("Beijing", "Asia/Shanghai", "China", ["Peking"]),
        ("Shenzhen", "Asia/Shanghai", "China", []),
        ("Guangzhou", "Asia/Shanghai", "China", ["Canton"]),
        ("San Francisco", "America/Los_Angeles", "US", ["SF", "Bay Area"]),
        ("Silicon Valley", "America/Los_Angeles", "US", ["Cupertino", "Palo Alto"]),
        ("Dallas", "America/Chicago", "US", ["DFW"]),
        ("Houston", "America/Chicago", "US", []),
        ("Austin", "America/Chicago", "US", []),
        ("Miami", "America/New_York", "US", []),
        ("Boston", "America/New_York", "US", []),
        ("Washington DC", "America/New_York", "US", ["DC"]),
        ("Philadelphia", "America/New_York", "US", ["Philly"]),
        ("Atlanta", "America/New_York", "US", []),
        ("Seattle", "America/Los_Angeles", "US", []),
        ("Las Vegas", "America/Los_Angeles", "US", ["Vegas"]),
        ("Munich", "Europe/Berlin", "Germany", ["München"]),
        ("Frankfurt", "Europe/Berlin", "Germany", []),
        ("Hamburg", "Europe/Berlin", "Germany", []),
        ("Cologne", "Europe/Berlin", "Germany", ["Köln"]),
        ("Düsseldorf", "Europe/Berlin", "Germany", []),
        ("Stuttgart", "Europe/Berlin", "Germany", []),
        ("Barcelona", "Europe/Madrid", "Spain", []),
        ("Milan", "Europe/Rome", "Italy", ["Milano"]),
        ("Florence", "Europe/Rome", "Italy", ["Firenze"]),
        ("Venice", "Europe/Rome", "Italy", ["Venezia"]),
        ("Naples", "Europe/Rome", "Italy", ["Napoli"]),
        ("Edinburgh", "Europe/London", "UK", []),
        ("Manchester", "Europe/London", "UK", []),
        ("Liverpool", "Europe/London", "UK", []),
        ("Birmingham", "Europe/London", "UK", []),
        ("Dubai", "Asia/Dubai", "UAE", []),
        ("Abu Dhabi", "Asia/Dubai", "UAE", []),
        ("Cape Town", "Africa/Johannesburg", "South Africa", []),
        ("Melbourne", "Australia/Melbourne", "Australia", []),
        ("Brisbane", "Australia/Brisbane", "Australia", []),
        ("Perth", "Australia/Perth", "Australia", []),
        ("Auckland", "Pacific/Auckland", "New Zealand", []),
        ("Wellington", "Pacific/Auckland", "New Zealand", []),
        ("Osaka", "Asia/Tokyo", "Japan", []),
        ("Kyoto", "Asia/Tokyo", "Japan", []),
        ("Taipei", "Asia/Taipei", "Taiwan", []),
        ("Seoul", "Asia/Seoul", "South Korea", []),
        ("Busan", "Asia/Seoul", "South Korea", []),
        ("Moscow", "Europe/Moscow", "Russia", []),
        ("Saint Petersburg", "Europe/Moscow", "Russia", ["St Petersburg"]),
        ("São Paulo", "America/Sao_Paulo", "Brazil", ["Sao Paulo"]),
        ("Rio de Janeiro", "America/Sao_Paulo", "Brazil", ["Rio"]),
        ("Buenos Aires", "America/Argentina/Buenos_Aires", "Argentina", []),
        ("Mexico City", "America/Mexico_City", "Mexico", []),
        ("Bogotá", "America/Bogota", "Colombia", ["Bogota"]),
        ("Lima", "America/Lima", "Peru", []),
        ("Santiago", "America/Santiago", "Chile", []),
        ("Nairobi", "Africa/Nairobi", "Kenya", []),
        ("Lagos", "Africa/Lagos", "Nigeria", []),
        ("Cairo", "Africa/Cairo", "Egypt", []),
        ("Casablanca", "Africa/Casablanca", "Morocco", []),
        ("Doha", "Asia/Qatar", "Qatar", []),
        ("Riyadh", "Asia/Riyadh", "Saudi Arabia", []),
        ("Kuala Lumpur", "Asia/Kuala_Lumpur", "Malaysia", ["KL"]),
        ("Jakarta", "Asia/Jakarta", "Indonesia", []),
        ("Manila", "Asia/Manila", "Philippines", []),
        ("Ho Chi Minh City", "Asia/Ho_Chi_Minh", "Vietnam", ["Saigon"]),
        ("Hanoi", "Asia/Ho_Chi_Minh", "Vietnam", []),
        ("Texas", "America/Chicago", "US", ["TX"]),
    ]

    static let cities: [CityEntry] = {
        var entries: [CityEntry] = []

        // 1. Add alias cities first (manually curated, better names)
        for alias in cityAliases {
            entries.append(CityEntry(
                cityName: alias.name,
                timeZoneIdentifier: alias.tz,
                country: alias.country,
                aliases: alias.aliases
            ))
        }

        // 2. Add system timezone cities
        let knownIds = TimeZone.knownTimeZoneIdentifiers
        let aliasTimezones = Set(cityAliases.map(\.tz))

        for identifier in knownIds {
            let parts = identifier.split(separator: "/")
            guard parts.count >= 2 else { continue }

            let region = String(parts[0])
            let cityRaw = String(parts.last!)
            let cityName = cityRaw.replacingOccurrences(of: "_", with: " ")

            entries.append(CityEntry(
                cityName: cityName,
                timeZoneIdentifier: identifier,
                country: region,
                aliases: []
            ))
        }

        return entries.sorted { $0.cityName < $1.cityName }
    }()

    static func search(_ query: String) -> [CityEntry] {
        guard !query.isEmpty else { return cities }
        let lowered = query.lowercased()
        return cities.filter {
            $0.cityName.lowercased().contains(lowered) ||
            $0.timeZoneIdentifier.lowercased().contains(lowered) ||
            $0.country.lowercased().contains(lowered) ||
            $0.aliases.contains(where: { $0.lowercased().contains(lowered) })
        }
    }
}
