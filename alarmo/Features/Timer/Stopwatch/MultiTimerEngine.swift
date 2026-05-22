import SwiftUI
import Combine

// MARK: - Single Parallel Timer

class ParallelTimer: ObservableObject, Identifiable {

    let id: UUID
    enum State { case idle, running, paused }

    @Published var name: String
    @Published var tag: String
    @Published var colorHex: TimerColor
    @Published var elapsed: TimeInterval = 0
    @Published var state: State = .idle

    private var startDate: Date?
    private var accumulated: TimeInterval = 0
    private var cancellable: AnyCancellable?

    enum TimerColor: String, CaseIterable, Codable {
        case teal, blue, purple, orange, pink, green
        var color: Color {
            switch self {
            case .teal:   return Color(red: 0.08, green: 0.78, blue: 0.92)
            case .blue:   return Color(red: 0.20, green: 0.50, blue: 0.95)
            case .purple: return Color(red: 0.60, green: 0.25, blue: 0.92)
            case .orange: return Color(red: 0.95, green: 0.55, blue: 0.15)
            case .pink:   return Color(red: 0.95, green: 0.25, blue: 0.65)
            case .green:  return Color(red: 0.20, green: 0.78, blue: 0.45)
            }
        }
    }

    init(id: UUID = UUID(), name: String, tag: String = "", color: TimerColor = .teal) {
        self.id = id
        self.name = name
        self.tag = tag
        self.colorHex = color
    }

    func start() {
        guard state != .running else { return }
        startDate = Date()
        state = .running
        cancellable = Timer.publish(every: 0.05, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, let start = self.startDate else { return }
                self.elapsed = self.accumulated + Date().timeIntervalSince(start)
            }
    }

    func pause() {
        accumulated = elapsed
        state = .paused
        cancellable?.cancel()
    }

    func resume() {
        startDate = Date()
        state = .running
        cancellable = Timer.publish(every: 0.05, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, let start = self.startDate else { return }
                self.elapsed = self.accumulated + Date().timeIntervalSince(start)
            }
    }

    func reset() {
        accumulated = 0
        elapsed = 0
        startDate = nil
        state = .idle
        cancellable?.cancel()
    }

    var timeDisplay: String { swFormatTime(elapsed, showHundredths: false) }
}

// MARK: - Multi Timer Store

class MultiTimerStore: ObservableObject {

    @Published var timers: [ParallelTimer] = []

    static let colorCycle: [ParallelTimer.TimerColor] = [.teal, .blue, .purple, .orange, .pink, .green]

    func addTimer(name: String, tag: String = "") {
        let colorIndex = timers.count % MultiTimerStore.colorCycle.count
        let t = ParallelTimer(name: name, tag: tag, color: MultiTimerStore.colorCycle[colorIndex])
        timers.append(t)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func remove(_ timer: ParallelTimer) {
        timers.removeAll { $0.id == timer.id }
    }

    func remove(at offsets: IndexSet) {
        timers.remove(atOffsets: offsets)
    }

    var anyRunning: Bool {
        timers.contains { $0.state == .running }
    }

    func pauseAll() {
        timers.filter { $0.state == .running }.forEach { $0.pause() }
    }

    func resumeAll() {
        timers.filter { $0.state == .paused }.forEach { $0.resume() }
    }

    func startOrResumeAll() {
        timers.forEach { timer in
            switch timer.state {
            case .idle:
                timer.start()
            case .paused:
                timer.resume()
            case .running:
                break
            }
        }
    }

    func resetAll() {
        timers.forEach { $0.reset() }
    }
}
