import SwiftUI
import Combine
import UserNotifications

// MARK: - Countdown Preset Model

struct CountdownPreset: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var emoji: String
    var duration: TimeInterval   // in seconds
    var color: CodableColor
    var autoRepeat: Bool = false
    var repeatCount: Int = 1     // 0 = infinite

    struct CodableColor: Codable, Equatable {
        var r: Double; var g: Double; var b: Double
        var swiftUIColor: Color { Color(red: r, green: g, blue: b) }
        static func from(_ color: Color) -> CodableColor {
            // Defaults for preset colors
            return CodableColor(r: 0.08, g: 0.78, b: 0.92)
        }
    }

    static let defaults: [CountdownPreset] = [
        CountdownPreset(name: "Coffee Brew", emoji: "☕️", duration: 4 * 60,
                        color: CodableColor(r: 0.72, g: 0.45, b: 0.20)),
        CountdownPreset(name: "Power Nap", emoji: "😴", duration: 20 * 60,
                        color: CodableColor(r: 0.35, g: 0.28, b: 0.80)),
        CountdownPreset(name: "Standup", emoji: "🤝", duration: 15 * 60,
                        color: CodableColor(r: 0.08, g: 0.78, b: 0.92)),
        CountdownPreset(name: "Lunch Break", emoji: "🍱", duration: 30 * 60,
                        color: CodableColor(r: 0.20, green: 0.78, blue: 0.35)),
        CountdownPreset(name: "Quick Stretch", emoji: "🧘", duration: 5 * 60,
                        color: CodableColor(r: 0.90, g: 0.55, b: 0.20)),
        CountdownPreset(name: "Meeting Limit", emoji: "📋", duration: 45 * 60,
                        color: CodableColor(r: 0.88, g: 0.22, b: 0.22)),
    ]
}

extension CountdownPreset.CodableColor {
    init(r: Double, green: Double, blue: Double) {
        self.r = r; self.g = green; self.b = blue
    }
}

// MARK: - Countdown Engine

class CountdownEngine: ObservableObject {

    enum State { case idle, running, paused, finished }

    @Published var remaining: TimeInterval
    @Published var state: State = .idle
    @Published var currentRepeat: Int = 1
    @Published var preset: CountdownPreset

    var onComplete: (() -> Void)?
    var onRepeat: ((Int) -> Void)?

    private var startDate: Date?
    private var remainingAtResume: TimeInterval
    private var timerCancellable: AnyCancellable?
    private var notificationActionCancellables = Set<AnyCancellable>()
    private let notificationOrchestrator = NotificationOrchestrator.shared
    private var pendingFinishNotificationId: String?

    init(preset: CountdownPreset) {
        self.preset = preset
        self.remaining = preset.duration
        self.remainingAtResume = preset.duration
        bindNotificationActions()
    }

    var progress: Double {
        guard preset.duration > 0 else { return 0 }
        return 1.0 - (remaining / preset.duration)
    }

    func start() {
        guard state != .running else { return }
        if state == .finished || remaining <= 0 {
            remaining = preset.duration
            remainingAtResume = preset.duration
            currentRepeat = 1
        }
        remainingAtResume = remaining
        startDate = Date()
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
        timerCancellable?.cancel()
        cancelFinishNotification()
        remaining = preset.duration
        remainingAtResume = preset.duration
        currentRepeat = 1
        startDate = nil
        state = .idle
    }

    func updatePreset(_ newPreset: CountdownPreset) {
        preset = newPreset
        reset()
    }

    func adjustRemainingTime(to seconds: Int) {
        remaining = TimeInterval(seconds)
        remainingAtResume = remaining
        if state == .running {
            startDate = Date()
            scheduleFinishNotification(after: remaining)
        }
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
            scheduleFinishNotification(after: remaining)
            startTick()
        } else {
            state = .finished
            publishFinishedNotification()
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

class CountdownPresetStore: ObservableObject {
    @Published var presets: [CountdownPreset] = []

    init() {
        load()
        if presets.isEmpty {
            presets = CountdownPreset.defaults
        }
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

    private func save() {
        if let data = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(data, forKey: "countdown_presets")
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: "countdown_presets"),
           let decoded = try? JSONDecoder().decode([CountdownPreset].self, from: data) {
            presets = decoded
        }
    }
}
