import Foundation
import Combine
import SwiftUI

/// Manages persistence and state for Overlap cities.
class OverlapStore: ObservableObject {
    static let shared = OverlapStore()

    @Published var cities: [OverlapCity] = []
    @Published var timeOffsetMinutes: Int = 0
    @Published var referenceTimeZone: TimeZone = .current

    private let storageKey = "overlapCities_v2"

    init() {
        load()
        referenceTimeZone = .current
    }

    // MARK: - CRUD

    func addCity(_ city: OverlapCity) {
        var newCity = city
        newCity.sortOrder = (cities.map(\.sortOrder).max() ?? 0) + 1
        cities.append(newCity)
        save()
    }

    func removeCity(id: UUID) {
        cities.removeAll { $0.id == id }
        save()
    }

    func moveCity(fromOffsets: IndexSet, toOffset: Int) {
        var sorted = sortedCities
        sorted.move(fromOffsets: fromOffsets, toOffset: toOffset)
        
        // Re-assign sort orders
        for (index, _) in sorted.enumerated() {
            if let cityIndex = cities.firstIndex(where: { $0.id == sorted[index].id }) {
                cities[cityIndex].sortOrder = index
            }
        }
        save()
    }

    func updateCity(_ city: OverlapCity) {
        if let index = cities.firstIndex(where: { $0.id == city.id }) {
            cities[index] = city
            save()
        }
    }

    func toggleMinimized(id: UUID) {
        if let index = cities.firstIndex(where: { $0.id == id }) {
            cities[index].isMinimized.toggle()
            save()
        }
    }

    func toggleStar(id: UUID) {
        if let index = cities.firstIndex(where: { $0.id == id }) {
            cities[index].isStarred.toggle()
            save()
        }
    }

    /// All cities sorted by sort order (minimized ones included but shown differently).
    var sortedCities: [OverlapCity] {
        cities.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// All cities that are visible (not minimized), sorted.
    var visibleCities: [OverlapCity] {
        sortedCities.filter { !$0.isMinimized }
    }

    /// The effective "now" with offset applied.
    var adjustedDate: Date {
        Date().addingTimeInterval(Double(timeOffsetMinutes) * 60)
    }

    /// Reset time offset to "now"
    func resetToNow() {
        timeOffsetMinutes = 0
    }

    // MARK: - Overlap Calculation

    func findOverlap(for cityIds: [UUID], on date: Date? = nil) -> (start: Int, end: Int)? {
        let refDate = date ?? adjustedDate
        let refTZ = referenceTimeZone

        let selectedCities = cities.filter { cityIds.contains($0.id) }
        guard selectedCities.count >= 2 else { return nil }

        var intervals: [(start: Int, end: Int)] = []

        for city in selectedCities {
            let offsetSeconds = city.timeZone.secondsFromGMT(for: refDate) - refTZ.secondsFromGMT(for: refDate)
            let offsetMinutes = offsetSeconds / 60

            let startInRef = city.availabilityStart - offsetMinutes
            let endInRef = city.availabilityEnd - offsetMinutes

            intervals.append((start: startInRef, end: endInRef))
        }

        let overlapStart = intervals.map(\.start).max() ?? 0
        let overlapEnd = intervals.map(\.end).min() ?? 0

        if overlapEnd <= overlapStart {
            return nil
        }

        return (start: overlapStart, end: overlapEnd)
    }

    /// Format minutes from midnight to time string
    static func formatMinutes(_ minutes: Int) -> String {
        let h = (minutes / 60) % 24
        let m = minutes % 60
        return String(format: "%02d:%02d", (h + 24) % 24, m)
    }

    // MARK: - Best Meeting Times

    struct MeetingSlot: Identifiable {
        let id = UUID()
        let startMinutes: Int
        let endMinutes: Int
        let score: Double

        var startFormatted: String { OverlapStore.formatMinutes(startMinutes) }
        var endFormatted: String { OverlapStore.formatMinutes(endMinutes) }
        var durationMinutes: Int { endMinutes - startMinutes }
    }

    func bestMeetingSlots(for selectedIds: [UUID]? = nil) -> [MeetingSlot] {
        let visible = sortedCities.filter { city in
            !city.isMinimized && (selectedIds == nil || selectedIds!.contains(city.id))
        }
        guard visible.count >= 2 else { return [] }

        let refDate = adjustedDate
        var slots: [MeetingSlot] = []

        for startMin in stride(from: 0, to: 1440, by: 30) {
            let endMin = startMin + 60

            var allAvailable = true
            var score: Double = 1.0

            for city in visible {
                let offsetSeconds = city.timeZone.secondsFromGMT(for: refDate) - referenceTimeZone.secondsFromGMT(for: refDate)
                let offsetMinutes = offsetSeconds / 60

                let cityStart = startMin + offsetMinutes
                let cityEnd = endMin + offsetMinutes

                let normalizedStart = ((cityStart % 1440) + 1440) % 1440
                let normalizedEnd = ((cityEnd % 1440) + 1440) % 1440

                let availStart = city.availabilityStart - city.flexMinutesBefore
                let availEnd = city.availabilityEnd + city.flexMinutesAfter

                if normalizedStart < availStart || normalizedEnd > availEnd {
                    allAvailable = false
                    break
                }

                if normalizedStart < city.availabilityStart || normalizedEnd > city.availabilityEnd {
                    score *= 0.7
                }
            }

            if allAvailable {
                slots.append(MeetingSlot(startMinutes: startMin, endMinutes: endMin, score: score))
            }
        }

        return slots.sorted { $0.score > $1.score }
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(cities) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([OverlapCity].self, from: data) else {
            return
        }
        cities = decoded
    }
}
