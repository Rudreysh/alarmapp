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

    /// Whether it's daytime (6am–8pm) in this city at the given date.
    func isDaytime(at date: Date) -> Bool {
        let cal = Calendar.current
        var calInTZ = cal
        calInTZ.timeZone = timeZone
        let hour = calInTZ.component(.hour, from: date)
        return hour >= 6 && hour < 20
    }

    /// Country flag emoji derived from the timezone identifier.
    var flagEmoji: String {
        WorldCityDatabase.flagEmoji(forTimeZone: timeZoneIdentifier)
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
        ("London", "Europe/London", "UK", []),
        ("Paris", "Europe/Paris", "France", []),
        ("Berlin", "Europe/Berlin", "Germany", []),
        ("Tokyo", "Asia/Tokyo", "Japan", []),
        ("New York", "America/New_York", "USA", ["NYC", "Manhattan"]),
        ("San Francisco", "America/Los_Angeles", "USA", ["SF", "Bay Area"]),
        ("Silicon Valley", "America/Los_Angeles", "USA", ["Cupertino", "Palo Alto"]),
        ("Dallas", "America/Chicago", "USA", ["DFW"]),
        ("Houston", "America/Chicago", "USA", []),
        ("Austin", "America/Chicago", "USA", []),
        ("Miami", "America/New_York", "USA", []),
        ("Boston", "America/New_York", "USA", []),
        ("Washington DC", "America/New_York", "USA", ["DC"]),
        ("Philadelphia", "America/New_York", "USA", ["Philly"]),
        ("Atlanta", "America/New_York", "USA", []),
        ("Seattle", "America/Los_Angeles", "USA", []),
        ("Las Vegas", "America/Los_Angeles", "USA", ["Vegas"]),
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
        ("Rome", "Europe/Rome", "Italy", ["Roma"]),
        ("Madrid", "Europe/Madrid", "Spain", []),
        ("Amsterdam", "Europe/Amsterdam", "Netherlands", []),
        ("Brussels", "Europe/Brussels", "Belgium", []),
        ("Zurich", "Europe/Zurich", "Switzerland", ["Zürich"]),
        ("Vienna", "Europe/Vienna", "Austria", ["Wien"]),
        ("Stockholm", "Europe/Stockholm", "Sweden", []),
        ("Oslo", "Europe/Oslo", "Norway", []),
        ("Copenhagen", "Europe/Copenhagen", "Denmark", ["København"]),
        ("Helsinki", "Europe/Helsinki", "Finland", []),
        ("Lisbon", "Europe/Lisbon", "Portugal", ["Lisboa"]),
        ("Athens", "Europe/Athens", "Greece", []),
        ("Dublin", "Europe/Dublin", "Ireland", []),
        ("Warsaw", "Europe/Warsaw", "Poland", ["Warszawa"]),
        ("Prague", "Europe/Prague", "Czech Republic", ["Praha"]),
        ("Budapest", "Europe/Budapest", "Hungary", []),
        ("Istanbul", "Europe/Istanbul", "Turkey", ["Constantinople"]),
        ("Tel Aviv", "Asia/Jerusalem", "Israel", []),
        ("Cairo", "Africa/Cairo", "Egypt", []),
        ("Nairobi", "Africa/Nairobi", "Kenya", []),
        ("Johannesburg", "Africa/Johannesburg", "South Africa", ["Joburg"]),
        ("Lagos", "Africa/Lagos", "Nigeria", []),
        ("Nairobi", "Africa/Nairobi", "Kenya", []),
        ("Casablanca", "Africa/Casablanca", "Morocco", []),
        ("Bangkok", "Asia/Bangkok", "Thailand", ["Krung Thep"]),
        ("Singapore", "Asia/Singapore", "Singapore", []),
        ("Hong Kong", "Asia/Hong_Kong", "Hong Kong", ["HK"]),
        ("Jakarta", "Asia/Jakarta", "Indonesia", []),
        ("Manila", "Asia/Manila", "Philippines", []),
        ("Sydney", "Australia/Sydney", "Australia", []),
        ("Toronto", "America/Toronto", "Canada", []),
        ("Vancouver", "America/Vancouver", "Canada", []),
        ("Montreal", "America/Toronto", "Canada", ["Montréal"]),
        ("Ottawa", "America/Toronto", "Canada", []),
        ("Vancouver", "America/Vancouver", "Canada", []),
        ("Denver", "America/Denver", "USA", ["Mile High City"]),
        ("Phoenix", "America/Phoenix", "USA", []),
        ("Salt Lake City", "America/Denver", "USA", ["SLC"]),
        ("Saint Paul", "America/Chicago", "USA", []),
        ("Minneapolis", "America/Chicago", "USA", []),
        ("Detroit", "America/New_York", "USA", []),
        ("Portland", "America/Los_Angeles", "USA", []),
        ("San Diego", "America/Los_Angeles", "USA", []),
        ("Honolulu", "Pacific/Honolulu", "USA", []),
        ("Anchorage", "America/Anchorage", "USA", []),
        ("Mexico City", "America/Mexico_City", "Mexico", ["CDMX"]),
        ("Lima", "America/Lima", "Peru", []),
        ("Bogotá", "America/Bogota", "Colombia", ["Bogota"]),
        ("Santiago", "America/Santiago", "Chile", []),
        ("Caracas", "America/Caracas", "Venezuela", []),
        ("Quito", "America/Guayaquil", "Ecuador", []),
        ("Asunción", "America/Asuncion", "Paraguay", ["Asuncion"]),
        ("Montevideo", "America/Montevideo", "Uruguay", []),
        ("Panama City", "America/Panama", "Panama", []),
        ("San José", "America/Costa_Rica", "Costa Rica", ["San Jose"]),
        ("Havana", "America/Havana", "Cuba", []),
        ("Santo Domingo", "America/Santo_Domingo", "Dominican Republic", []),
        ("San Juan", "America/Puerto_Rico", "Puerto Rico", []),
        ("Port of Spain", "America/Port_of_Spain", "Trinidad and Tobago", []),
        ("Kingston", "America/Jamaica", "Jamaica", []),
        ("Nassau", "America/Nassau", "Bahamas", []),
        ("Reykjavik", "Atlantic/Reykjavik", "Iceland", ["Reykjavík"]),
        ("Moscow", "Europe/Moscow", "Russia", []),
        ("Saint Petersburg", "Europe/Moscow", "Russia", ["St Petersburg"]),
        ("Kyiv", "Europe/Kyiv", "Ukraine", ["Kiev"]),
        ("Bucharest", "Europe/Bucharest", "Romania", []),
        ("Sofia", "Europe/Sofia", "Bulgaria", []),
        ("Belgrade", "Europe/Belgrade", "Serbia", []),
        ("Zagreb", "Europe/Zagreb", "Croatia", []),
        ("Bratislava", "Europe/Bratislava", "Slovakia", []),
        ("Ljubljana", "Europe/Ljubljana", "Slovenia", []),
        ("Tallinn", "Europe/Tallinn", "Estonia", []),
        ("Riga", "Europe/Riga", "Latvia", []),
        ("Vilnius", "Europe/Vilnius", "Lithuania", []),
        ("Tbilisi", "Asia/Tbilisi", "Georgia", []),
        ("Yerevan", "Asia/Yerevan", "Armenia", []),
        ("Baku", "Asia/Baku", "Azerbaijan", []),
        ("Tehran", "Asia/Tehran", "Iran", []),
        ("Baghdad", "Asia/Baghdad", "Iraq", []),
        ("Kuwait City", "Asia/Kuwait", "Kuwait", []),
        ("Muscat", "Asia/Muscat", "Oman", []),
        ("Manama", "Asia/Bahrain", "Bahrain", []),
        ("Amman", "Asia/Amman", "Jordan", []),
        ("Beirut", "Asia/Beirut", "Lebanon", []),
        ("Damascus", "Asia/Damascus", "Syria", []),
        ("Jerusalem", "Asia/Jerusalem", "Israel", []),
        ("Tashkent", "Asia/Tashkent", "Uzbekistan", []),
        ("Almaty", "Asia/Almaty", "Kazakhstan", []),
        ("Nur-Sultan", "Asia/Almaty", "Kazakhstan", ["Astana"]),
        ("Islamabad", "Asia/Karachi", "Pakistan", []),
        ("Karachi", "Asia/Karachi", "Pakistan", []),
        ("Dhaka", "Asia/Dhaka", "Bangladesh", []),
        ("Kathmandu", "Asia/Kathmandu", "Nepal", []),
        ("Colombo", "Asia/Colombo", "Sri Lanka", []),
        ("Male", "Indian/Maldives", "Maldives", []),
        ("Ulaanbaatar", "Asia/Ulaanbaatar", "Mongolia", []),
        ("Pyongyang", "Asia/Pyongyang", "North Korea", []),
        ("Phnom Penh", "Asia/Phnom_Penh", "Cambodia", []),
        ("Vientiane", "Asia/Vientiane", "Laos", []),
        ("Yangon", "Asia/Rangoon", "Myanmar", ["Rangoon"]),
        ("Antananarivo", "Indian/Antananarivo", "Madagascar", []),
        ("Addis Ababa", "Africa/Addis_Ababa", "Ethiopia", []),
        ("Dakar", "Africa/Dakar", "Senegal", []),
        ("Accra", "Africa/Accra", "Ghana", []),
        ("Abidjan", "Africa/Abidjan", "Ivory Coast", []),
        ("Luanda", "Africa/Luanda", "Angola", []),
        ("Dar es Salaam", "Africa/Dar_es_Salaam", "Tanzania", []),
        ("Kampala", "Africa/Kampala", "Uganda", []),
        ("Algiers", "Africa/Algiers", "Algeria", []),
        ("Tunis", "Africa/Tunis", "Tunisia", []),
        ("Tripoli", "Africa/Tripoli", "Libya", []),
        ("Khartoum", "Africa/Khartoum", "Sudan", []),

    ]

    static let majorCities: [CityEntry] = {
        cityAliases.map { alias in
            CityEntry(
                cityName: alias.name,
                timeZoneIdentifier: alias.tz,
                country: alias.country,
                aliases: alias.aliases
            )
        }
    }()

    /// Popular suggestions grouped by region: US first, then Europe, Asia, then others.
    static let suggestedCities: [CityEntry] = {
        var uniqueByCountry: [CityEntry] = []
        var seenCountries = Set<String>()

        for alias in cityAliases {
            let canonicalCountry = canonicalCountryName(alias.country)
            guard !seenCountries.contains(canonicalCountry) else { continue }
            seenCountries.insert(canonicalCountry)

            uniqueByCountry.append(
                CityEntry(
                    cityName: alias.name,
                    timeZoneIdentifier: alias.tz,
                    country: canonicalCountry,
                    aliases: alias.aliases
                )
            )
        }

        let us = uniqueByCountry
            .filter { $0.country == "United States" }
            .sorted(by: countryThenCity)
        let europe = uniqueByCountry
            .filter { europeanCountries.contains($0.country) }
            .sorted(by: countryThenCity)
        let asia = uniqueByCountry
            .filter { asianCountries.contains($0.country) }
            .sorted(by: countryThenCity)
        let other = uniqueByCountry
            .filter { !($0.country == "United States" || europeanCountries.contains($0.country) || asianCountries.contains($0.country)) }
            .sorted(by: countryThenCity)

        return us + europe + asia + other
    }()

    private static let europeanCountries: Set<String> = [
        "Austria", "Belgium", "Bulgaria", "Croatia", "Czech Republic",
        "Denmark", "Estonia", "Finland", "France", "Germany", "Greece",
        "Hungary", "Iceland", "Ireland", "Italy", "Latvia", "Lithuania",
        "Netherlands", "Norway", "Poland", "Portugal", "Romania", "Russia",
        "Serbia", "Slovakia", "Slovenia", "Spain", "Sweden", "Switzerland",
        "Turkey", "Ukraine", "United Kingdom"
    ]

    private static let asianCountries: Set<String> = [
        "Armenia", "Azerbaijan", "Bahrain", "Bangladesh", "Cambodia",
        "China", "Georgia", "Hong Kong", "India", "Indonesia", "Iran",
        "Iraq", "Israel", "Japan", "Jordan", "Kazakhstan", "Kuwait",
        "Laos", "Lebanon", "Malaysia", "Maldives", "Mongolia", "Myanmar",
        "Nepal", "North Korea", "Oman", "Pakistan", "Philippines", "Qatar",
        "Saudi Arabia", "Singapore", "South Korea", "Sri Lanka", "Syria",
        "Taiwan", "Thailand", "UAE", "Uzbekistan", "Vietnam"
    ]

    private static func canonicalCountryName(_ rawCountry: String) -> String {
        switch rawCountry.lowercased() {
        case "us", "usa", "united states", "united states of america":
            return "United States"
        case "uk", "u.k.", "great britain":
            return "United Kingdom"
        default:
            return rawCountry
        }
    }

    private static func countryThenCity(_ lhs: CityEntry, _ rhs: CityEntry) -> Bool {
        if lhs.country == rhs.country {
            return lhs.cityName < rhs.cityName
        }
        return lhs.country < rhs.country
    }

    static func flagEmoji(forTimeZone timeZoneIdentifier: String, countryHint: String? = nil) -> String {
        if let code = aliasTimeZoneCountryCode[timeZoneIdentifier] {
            return flagEmoji(forCountryCode: code)
        }

        if let hint = countryHint, let code = countryCode(forCountryName: canonicalCountryName(hint)) {
            return flagEmoji(forCountryCode: code)
        }

        return "🌐"
    }

    private static let aliasTimeZoneCountryCode: [String: String] = {
        var map: [String: String] = [:]
        for alias in cityAliases {
            let canonical = canonicalCountryName(alias.country)
            guard let code = countryCode(forCountryName: canonical) else { continue }
            if map[alias.tz] == nil {
                map[alias.tz] = code
            }
        }
        return map
    }()

    private static let countryNameToCodeIndex: [String: String] = {
        let locale = Locale(identifier: "en_US_POSIX")
        var index: [String: String] = [:]

        for code in Locale.Region.isoRegions.map(\.identifier) {
            if let name = locale.localizedString(forRegionCode: code) {
                index[normalizeCountryKey(name)] = code
            }
        }

        return index
    }()

    private static let countryCodeOverrides: [String: String] = [
        "usa": "US",
        "us": "US",
        "unitedstates": "US",
        "unitedstatesofamerica": "US",
        "uk": "GB",
        "unitedkingdom": "GB",
        "greatbritain": "GB",
        "uae": "AE",
        "hongkong": "HK",
        "taiwan": "TW",
        "southkorea": "KR",
        "northkorea": "KP",
        "czechrepublic": "CZ",
        "ivorycoast": "CI"
    ]

    private static func countryCode(forCountryName countryName: String) -> String? {
        let normalized = normalizeCountryKey(countryName)
        if let overridden = countryCodeOverrides[normalized] {
            return overridden
        }
        return countryNameToCodeIndex[normalized]
    }

    private static func normalizeCountryKey(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]", with: "", options: .regularExpression)
    }

    private static func flagEmoji(forCountryCode countryCode: String) -> String {
        let uppercase = countryCode.uppercased()
        guard uppercase.count == 2 else { return "🌐" }

        let base: UInt32 = 127_397
        let scalars = uppercase.unicodeScalars.compactMap { UnicodeScalar(base + $0.value) }
        guard scalars.count == 2 else { return "🌐" }
        return String(String.UnicodeScalarView(scalars))
    }

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
