import SwiftUI
import Combine
import UserNotifications

// MARK: - Countdown Preset Model

enum CountdownAudience: String, Codable, CaseIterable, Identifiable {
    case sports
    case gym
    case study
    case classroom
    case focus
    case everyday

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sports: return "Sports"
        case .gym: return "Gym"
        case .study: return "Students"
        case .classroom: return "Classroom"
        case .focus: return "Focus"
        case .everyday: return "Everyday"
        }
    }

    var icon: String {
        switch self {
        case .sports: return "figure.run"
        case .gym: return "dumbbell.fill"
        case .study: return "book.fill"
        case .classroom: return "person.3.sequence.fill"
        case .focus: return "brain.head.profile"
        case .everyday: return "clock.fill"
        }
    }
}

struct CountdownPreset: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var emoji: String
    var duration: TimeInterval
    var color: CodableColor
    var autoRepeat: Bool
    var repeatCount: Int
    var audience: CountdownAudience
    var details: String
    var isSystemTemplate: Bool

    init(
        id: UUID = UUID(),
        name: String,
        emoji: String,
        duration: TimeInterval,
        color: CodableColor,
        autoRepeat: Bool = false,
        repeatCount: Int = 1,
        audience: CountdownAudience = .everyday,
        details: String = "",
        isSystemTemplate: Bool = false
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.duration = duration
        self.color = color
        self.autoRepeat = autoRepeat
        self.repeatCount = repeatCount
        self.audience = audience
        self.details = details
        self.isSystemTemplate = isSystemTemplate
    }

    struct CodableColor: Codable, Equatable {
        var r: Double
        var g: Double
        var b: Double

        var swiftUIColor: Color { Color(red: r, green: g, blue: b) }

        static func from(_ color: Color) -> CodableColor {
            guard let components = color.cgColor?.components, components.count >= 3 else {
                return CodableColor(r: 0.10, g: 0.66, b: 0.95)
            }
            return CodableColor(r: components[0], g: components[1], b: components[2])
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case emoji
        case duration
        case color
        case autoRepeat
        case repeatCount
        case audience
        case details
        case isSystemTemplate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        emoji = try container.decodeIfPresent(String.self, forKey: .emoji) ?? "⏱️"
        duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration) ?? 60
        color = try container.decodeIfPresent(CodableColor.self, forKey: .color)
            ?? CodableColor(r: 0.10, g: 0.66, b: 0.95)
        autoRepeat = try container.decodeIfPresent(Bool.self, forKey: .autoRepeat) ?? false
        repeatCount = try container.decodeIfPresent(Int.self, forKey: .repeatCount) ?? 1
        audience = try container.decodeIfPresent(CountdownAudience.self, forKey: .audience) ?? .everyday
        details = try container.decodeIfPresent(String.self, forKey: .details) ?? ""
        isSystemTemplate = try container.decodeIfPresent(Bool.self, forKey: .isSystemTemplate) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(emoji, forKey: .emoji)
        try container.encode(duration, forKey: .duration)
        try container.encode(color, forKey: .color)
        try container.encode(autoRepeat, forKey: .autoRepeat)
        try container.encode(repeatCount, forKey: .repeatCount)
        try container.encode(audience, forKey: .audience)
        try container.encode(details, forKey: .details)
        try container.encode(isSystemTemplate, forKey: .isSystemTemplate)
    }

    static let starterTemplates: [CountdownPreset] = [
        CountdownPreset(name: "Tabata 20/10", emoji: "🔥", duration: 20,
                        color: CodableColor(r: 0.12, g: 0.74, b: 0.98),
                        autoRepeat: true, repeatCount: 8, audience: .sports,
                        details: "8 rounds", isSystemTemplate: true),
        CountdownPreset(name: "Sprint Intervals", emoji: "🏃", duration: 30,
                        color: CodableColor(r: 0.20, g: 0.78, b: 0.45),
                        autoRepeat: true, repeatCount: 10, audience: .sports,
                        details: "10 reps", isSystemTemplate: true),
        CountdownPreset(name: "Match Prep", emoji: "⚽️", duration: 15 * 60,
                        color: CodableColor(r: 0.10, g: 0.66, b: 0.95),
                        audience: .sports,
                        details: "Warm-up block", isSystemTemplate: true),

        CountdownPreset(name: "Set Rest 60s", emoji: "🏋️", duration: 60,
                        color: CodableColor(r: 0.10, g: 0.66, b: 0.95),
                        autoRepeat: true, repeatCount: 10, audience: .gym,
                        details: "Strength sets", isSystemTemplate: true),
        CountdownPreset(name: "Set Rest 90s", emoji: "💪", duration: 90,
                        color: CodableColor(r: 0.20, g: 0.50, b: 0.95),
                        autoRepeat: true, repeatCount: 8, audience: .gym,
                        details: "Hypertrophy", isSystemTemplate: true),
        CountdownPreset(name: "EMOM 12", emoji: "⏱️", duration: 60,
                        color: CodableColor(r: 0.20, g: 0.78, b: 0.45),
                        autoRepeat: true, repeatCount: 12, audience: .gym,
                        details: "Every minute", isSystemTemplate: true),

        CountdownPreset(name: "Pomodoro 25", emoji: "🍅", duration: 25 * 60,
                        color: CodableColor(r: 0.10, g: 0.66, b: 0.95),
                        audience: .study,
                        details: "Focus sprint", isSystemTemplate: true),
        CountdownPreset(name: "Deep Study 50", emoji: "📚", duration: 50 * 60,
                        color: CodableColor(r: 0.12, g: 0.74, b: 0.98),
                        audience: .study,
                        details: "Long block", isSystemTemplate: true),
        CountdownPreset(name: "Exam Practice", emoji: "📝", duration: 90 * 60,
                        color: CodableColor(r: 0.20, g: 0.50, b: 0.95),
                        audience: .study,
                        details: "Timed paper", isSystemTemplate: true),

        CountdownPreset(name: "Class Quiz", emoji: "🎓", duration: 10 * 60,
                        color: CodableColor(r: 0.10, g: 0.66, b: 0.95),
                        audience: .classroom,
                        details: "Student round", isSystemTemplate: true),
        CountdownPreset(name: "Transition", emoji: "🔔", duration: 2 * 60,
                        color: CodableColor(r: 0.20, g: 0.78, b: 0.45),
                        audience: .classroom,
                        details: "Move to next task", isSystemTemplate: true),
        CountdownPreset(name: "Activity Station", emoji: "🧩", duration: 15 * 60,
                        color: CodableColor(r: 0.12, g: 0.74, b: 0.98),
                        audience: .classroom,
                        details: "Group rotation", isSystemTemplate: true),

        CountdownPreset(name: "Deep Work", emoji: "🧠", duration: 45 * 60,
                        color: CodableColor(r: 0.10, g: 0.66, b: 0.95),
                        audience: .focus,
                        details: "No interruptions", isSystemTemplate: true),
        CountdownPreset(name: "Meeting Limit", emoji: "📋", duration: 45 * 60,
                        color: CodableColor(r: 0.20, g: 0.50, b: 0.95),
                        audience: .focus,
                        details: "Keep meetings sharp", isSystemTemplate: true),
        CountdownPreset(name: "Break Reset", emoji: "☕️", duration: 5 * 60,
                        color: CodableColor(r: 0.20, g: 0.78, b: 0.45),
                        audience: .focus,
                        details: "Quick reset", isSystemTemplate: true),

        CountdownPreset(name: "Power Nap", emoji: "😴", duration: 20 * 60,
                        color: CodableColor(r: 0.20, g: 0.50, b: 0.95),
                        audience: .everyday,
                        details: "Recovery nap", isSystemTemplate: true),
        CountdownPreset(name: "Coffee Brew", emoji: "☕️", duration: 4 * 60,
                        color: CodableColor(r: 0.10, g: 0.66, b: 0.95),
                        audience: .everyday,
                        details: "Kitchen timer", isSystemTemplate: true),
        CountdownPreset(name: "Laundry", emoji: "🧺", duration: 30 * 60,
                        color: CodableColor(r: 0.12, g: 0.74, b: 0.98),
                        audience: .everyday,
                        details: "Home task", isSystemTemplate: true)
    ]

    static let defaults: [CountdownPreset] = starterTemplates
}

extension CountdownPreset.CodableColor {
    init(r: Double, green: Double, blue: Double) {
        self.r = r
        self.g = green
        self.b = blue
    }
}

// MARK: - Countdown Engine

final class CountdownEngine: ObservableObject {

    enum State { case idle, running, paused, finished }

    @Published var remaining: TimeInterval
    @Published var state: State = .idle
    @Published var currentRepeat: Int = 1
    @Published var preset: CountdownPreset

    var onComplete: (() -> Void)?
    var onRepeat: ((Int) -> Void)?
    var onFinalTenSeconds: ((Int) -> Void)?

    private var startDate: Date?
    private var sessionStartedAt: Date?
    private var remainingAtResume: TimeInterval
    private var timerCancellable: AnyCancellable?
    private var notificationActionCancellables = Set<AnyCancellable>()
    private let notificationOrchestrator = NotificationOrchestrator.shared
    private var pendingFinishNotificationId: String?
    private var lastNotifiedSecond: Int?

    private let historyStore: CountdownHistoryStore

    init(
        preset: CountdownPreset,
        historyStore: CountdownHistoryStore = .shared
    ) {
        self.preset = preset
        self.remaining = preset.duration
        self.remainingAtResume = preset.duration
        self.historyStore = historyStore
        bindNotificationActions()
    }

    var progress: Double {
        guard preset.duration > 0 else { return 0 }
        return 1.0 - (remaining / preset.duration)
    }

    var totalRoundsText: String {
        guard preset.autoRepeat else { return "1 / 1" }
        if preset.repeatCount == 0 {
            return "\(currentRepeat) / ∞"
        }
        return "\(currentRepeat) / \(preset.repeatCount)"
    }

    func start() {
        guard state != .running else { return }

        if state == .finished || remaining <= 0 {
            remaining = preset.duration
            remainingAtResume = preset.duration
            currentRepeat = 1
        }

        if state == .idle || state == .finished {
            sessionStartedAt = Date()
        }

        remainingAtResume = remaining
        startDate = Date()
        lastNotifiedSecond = nil
        state = .running
        scheduleFinishNotification(after: remaining)
        startTick()
    }

    func pause() {
        guard state == .running else { return }
        remaining = remainingAtResume - Date().timeIntervalSince(startDate ?? Date())
        remaining = max(0, remaining)
        remainingAtResume = remaining
        state = .paused
        timerCancellable?.cancel()
        cancelFinishNotification()
    }

    func reset() {
        if (state == .running || state == .paused), let sessionStartedAt, remaining < preset.duration {
            let elapsed = Date().timeIntervalSince(sessionStartedAt)
            historyStore.record(
                presetName: preset.name,
                audience: preset.audience,
                totalDuration: elapsed,
                completedCycles: max(1, currentRepeat),
                didComplete: false
            )
        }

        timerCancellable?.cancel()
        cancelFinishNotification()
        remaining = preset.duration
        remainingAtResume = preset.duration
        currentRepeat = 1
        startDate = nil
        sessionStartedAt = nil
        lastNotifiedSecond = nil
        state = .idle
    }

    func updatePreset(_ newPreset: CountdownPreset) {
        preset = newPreset
        reset()
    }

    func adjustRemainingTime(to seconds: Int) {
        remaining = TimeInterval(max(1, seconds))
        remainingAtResume = remaining
        if state == .running {
            startDate = Date()
            scheduleFinishNotification(after: remaining)
        }
    }

    func addSeconds(_ seconds: Int) {
        adjustRemainingTime(to: Int(remaining.rounded(.up)) + seconds)
    }

    func subtractSeconds(_ seconds: Int) {
        adjustRemainingTime(to: Int(remaining.rounded(.up)) - seconds)
    }

    private func startTick() {
        timerCancellable = Timer.publish(every: 0.01, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    private func tick() {
        guard let start = startDate else { return }
        let newRemaining = remainingAtResume - Date().timeIntervalSince(start)
        if newRemaining <= 0 {
            remaining = 0
            handleFinished()
        } else {
            remaining = newRemaining
            emitWarningCuesIfNeeded()
        }
    }

    private func emitWarningCuesIfNeeded() {
        let wholeSeconds = Int(ceil(remaining))
        guard wholeSeconds != lastNotifiedSecond else { return }
        lastNotifiedSecond = wholeSeconds

        if wholeSeconds == 10 {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        } else if wholeSeconds <= 3 {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        }

        if wholeSeconds <= 10 && wholeSeconds > 0 {
            onFinalTenSeconds?(wholeSeconds)
        }
    }

    private func handleFinished() {
        timerCancellable?.cancel()
        cancelFinishNotification()
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        let maxRepeats = preset.repeatCount
        let infinite = maxRepeats == 0

        if preset.autoRepeat && (infinite || currentRepeat < maxRepeats) {
            currentRepeat += 1
            onRepeat?(currentRepeat)
            publishRepeatCycleNotification()
            remaining = preset.duration
            remainingAtResume = preset.duration
            startDate = Date()
            lastNotifiedSecond = nil
            scheduleFinishNotification(after: remaining)
            startTick()
        } else {
            state = .finished
            publishFinishedNotification()

            let elapsed: TimeInterval
            if let sessionStartedAt {
                elapsed = Date().timeIntervalSince(sessionStartedAt)
            } else {
                elapsed = preset.duration * Double(max(1, currentRepeat))
            }

            historyStore.record(
                presetName: preset.name,
                audience: preset.audience,
                totalDuration: elapsed,
                completedCycles: max(1, currentRepeat),
                didComplete: true
            )

            onComplete?()
        }
    }

    private func scheduleFinishNotification(after seconds: TimeInterval) {
        cancelFinishNotification()
        guard seconds > 0 else { return }
        let id = "\(AppNotificationIdentifier.countdownFinish)-\(preset.id.uuidString)-\(UUID().uuidString)"
        pendingFinishNotificationId = id
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        notificationOrchestrator.schedule(
            identifier: id,
            scenario: .countdownFinished,
            trigger: trigger,
            context: AppNotificationContext(itemName: preset.name),
            categoryIdentifier: AppNotificationCategory.countdown,
            userInfo: [
                "scenario": AppNotificationScenario.countdownFinished.rawValue,
                "itemName": preset.name
            ],
            sound: .default
        )
    }

    private func cancelFinishNotification() {
        guard let id = pendingFinishNotificationId else { return }
        notificationOrchestrator.cancel(identifiers: [id])
        pendingFinishNotificationId = nil
    }

    private func publishFinishedNotification() {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        notificationOrchestrator.schedule(
            identifier: "alarmo.countdown.finished-now-\(UUID().uuidString)",
            scenario: .countdownFinished,
            trigger: trigger,
            context: AppNotificationContext(itemName: preset.name),
            categoryIdentifier: AppNotificationCategory.countdown,
            userInfo: [
                "scenario": AppNotificationScenario.countdownFinished.rawValue,
                "itemName": preset.name
            ],
            sound: .default
        )
    }

    private func publishRepeatCycleNotification() {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        notificationOrchestrator.schedule(
            identifier: "alarmo.countdown.repeat-\(UUID().uuidString)",
            scenario: .countdownCycleRepeat,
            trigger: trigger,
            context: AppNotificationContext(itemName: preset.name),
            categoryIdentifier: AppNotificationCategory.countdown,
            userInfo: [
                "scenario": AppNotificationScenario.countdownCycleRepeat.rawValue,
                "itemName": preset.name
            ],
            sound: .default
        )
    }

    private func bindNotificationActions() {
        NotificationCenter.default.publisher(for: .countdownAddMinuteRequestedFromNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                let updated = Int(self.remaining.rounded(.up)) + 60
                self.adjustRemainingTime(to: max(1, updated))
                if self.state == .finished {
                    self.state = .paused
                }
            }
            .store(in: &notificationActionCancellables)

        NotificationCenter.default.publisher(for: .countdownStopRequestedFromNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.reset()
            }
            .store(in: &notificationActionCancellables)
    }
}

// MARK: - Preset Store

final class CountdownPresetStore: ObservableObject {
    @Published var presets: [CountdownPreset] = []

    private let presetsKey = "countdown_presets"
    private let templateSeedVersionKey = "countdown_template_seed_version"
    private let currentTemplateSeedVersion = 2

    init() {
        load()
        ensureStarterTemplates()
    }

    func add(_ preset: CountdownPreset) {
        presets.insert(preset, at: 0)
        save()
    }

    func delete(at offsets: IndexSet) {
        presets.remove(atOffsets: offsets)
        save()
    }

    func move(from source: IndexSet, to destination: Int) {
        presets.move(fromOffsets: source, toOffset: destination)
        save()
    }

    func filtered(by audience: CountdownAudience?) -> [CountdownPreset] {
        guard let audience else { return presets }
        return presets.filter { $0.audience == audience }
    }

    private func ensureStarterTemplates() {
        let storedVersion = UserDefaults.standard.integer(forKey: templateSeedVersionKey)
        if presets.isEmpty {
            presets = CountdownPreset.starterTemplates
            save()
        } else if storedVersion < currentTemplateSeedVersion {
            var existingNames = Set(presets.map { $0.name.lowercased() })
            for template in CountdownPreset.starterTemplates {
                let key = template.name.lowercased()
                if !existingNames.contains(key) {
                    presets.append(template)
                    existingNames.insert(key)
                }
            }
            save()
        }

        UserDefaults.standard.set(currentTemplateSeedVersion, forKey: templateSeedVersionKey)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(data, forKey: presetsKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: presetsKey),
           let decoded = try? JSONDecoder().decode([CountdownPreset].self, from: data) {
            presets = decoded
        }
    }
}

// MARK: - Countdown History

struct CountdownHistoryEntry: Identifiable, Codable {
    var id: UUID = UUID()
    var timestamp: Date
    var presetName: String
    var audience: CountdownAudience
    var totalDuration: TimeInterval
    var completedCycles: Int
    var didComplete: Bool
}

final class CountdownHistoryStore: ObservableObject {
    static let shared = CountdownHistoryStore()

    @Published private(set) var entries: [CountdownHistoryEntry] = []

    private let storageKey = "countdown_history_entries"

    private init() {
        load()
    }

    func record(
        presetName: String,
        audience: CountdownAudience,
        totalDuration: TimeInterval,
        completedCycles: Int,
        didComplete: Bool
    ) {
        let entry = CountdownHistoryEntry(
            timestamp: Date(),
            presetName: presetName,
            audience: audience,
            totalDuration: totalDuration,
            completedCycles: completedCycles,
            didComplete: didComplete
        )
        entries.insert(entry, at: 0)
        if entries.count > 200 {
            entries = Array(entries.prefix(200))
        }
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([CountdownHistoryEntry].self, from: data)
        else {
            entries = []
            return
        }

        entries = decoded
    }
}
