import ActivityKit
import WidgetKit
import SwiftUI

@main
struct AlarmoWidgetBundle: WidgetBundle {
    var body: some Widget {
        AlarmoWidgetLiveActivity()
    }
}

struct AlarmoWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PomoAttributes.self) { context in
            let sessions = resolvedSessions(from: context.state, fallbackName: context.attributes.focusName)
            let active = resolvedActiveSession(from: context.state, fallbackName: context.attributes.focusName)
            let visibleSessions = Array(sessions.prefix(3))
            // Lock screen compact habit card
            VStack(spacing: 18) {
                ForEach(visibleSessions, id: \.id) { session in
                    lockScreenSessionRow(session: session, isActive: session.id == active.id, activeIsRunning: active.isRunning)
                }
                if sessions.count > visibleSessions.count {
                    Text("+\(sessions.count - visibleSessions.count) more running")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.75))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.65))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        } dynamicIsland: { context in
            let active = resolvedActiveSession(from: context.state, fallbackName: context.attributes.focusName)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Text(focusEmoji(from: active.focusName))
                            .font(.system(size: 20))
                        Text(active.focusName)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Button(intent: TogglePomoRunStateIntent()) {
                        Image(systemName: active.isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Color.white.opacity(0.22)))
                    }
                    .buttonStyle(.plain)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        timerText(
                            startTime: active.startTime,
                            endTime: active.endTime,
                            remainingSeconds: active.remainingSeconds,
                            isRunning: active.isRunning,
                            size: 22,
                            color: .orange,
                            width: nil
                        )
                        Spacer()
                        Text(context.state.stateString)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 8)
                }
            } compactLeading: {
                Text(focusEmoji(from: active.focusName))
            } compactTrailing: {
                timerText(
                    startTime: active.startTime,
                    endTime: active.endTime,
                    remainingSeconds: active.remainingSeconds,
                    isRunning: active.isRunning,
                    size: 14,
                    color: .orange,
                    width: 45
                )
            } minimal: {
                Text(focusEmoji(from: active.focusName))
            }
            .keylineTint(Color.orange)
        }
    }

    private struct LockScreenProgressRing: View {
        let startTime: Date
        let endTime: Date
        let remainingSeconds: Int
        let isRunning: Bool
        let diameter: CGFloat
        let lineWidth: CGFloat

        init(
            startTime: Date,
            endTime: Date,
            remainingSeconds: Int,
            isRunning: Bool,
            diameter: CGFloat = 72,
            lineWidth: CGFloat = 7
        ) {
            self.startTime = startTime
            self.endTime = endTime
            self.remainingSeconds = remainingSeconds
            self.isRunning = isRunning
            self.diameter = diameter
            self.lineWidth = lineWidth
        }

        var body: some View {
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                Circle()
                    .trim(from: 0, to: elapsedFraction(at: timeline.date))
                    .stroke(
                        Color(red: 0.62, green: 0.52, blue: 0.96),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: diameter, height: diameter)
            }
        }

        private func elapsedFraction(at now: Date) -> Double {
            let total = max(1.0, endTime.timeIntervalSince(startTime))
            let elapsed: Double
            if isRunning {
                elapsed = now.timeIntervalSince(startTime)
            } else {
                elapsed = total - Double(remainingSeconds)
            }
            return min(max(elapsed / total, 0), 1)
        }
    }

    @ViewBuilder
    private func lockScreenSessionRow(
        session: PomoAttributes.ContentState.ParallelSession,
        isActive: Bool,
        activeIsRunning: Bool
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.20), lineWidth: 6)
                    .frame(width: 52, height: 52)

                LockScreenProgressRing(
                    startTime: session.startTime,
                    endTime: session.endTime,
                    remainingSeconds: session.remainingSeconds,
                    isRunning: session.isRunning,
                    diameter: 52,
                    lineWidth: 6
                )

                Text(focusEmoji(from: session.focusName))
                    .font(.system(size: 22))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(session.focusName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                timerText(
                    startTime: session.startTime,
                    endTime: session.endTime,
                    remainingSeconds: session.remainingSeconds,
                    isRunning: session.isRunning,
                    size: 16,
                    color: .white,
                    width: nil
                )
            }

            Spacer(minLength: 8)

            if isActive {
                Button(intent: TogglePomoRunStateIntent()) {
                    Image(systemName: activeIsRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black.opacity(0.88))
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.white))
                }
                .buttonStyle(.plain)
            } else {
                Circle()
                    .fill(session.isRunning ? Color.green.opacity(0.9) : Color.gray.opacity(0.7))
                    .frame(width: 10, height: 10)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func timerText(
        startTime: Date,
        endTime: Date,
        remainingSeconds: Int,
        isRunning: Bool,
        size: CGFloat,
        color: Color,
        width: CGFloat?
    ) -> some View {
        if isRunning {
            Text(timerInterval: startTime...endTime, countsDown: true)
                .multilineTextAlignment(.leading)
                .font(.system(size: size, weight: .heavy, design: .monospaced))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: width, alignment: .leading)
        } else {
            Text(formattedClock(remainingSeconds))
                .multilineTextAlignment(.leading)
                .font(.system(size: size, weight: .heavy, design: .monospaced))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: width, alignment: .leading)
        }
    }

    private func formattedClock(_ seconds: Int) -> String {
        let clamped = max(0, seconds)
        let hours = clamped / 3600
        let minutes = (clamped % 3600) / 60
        let secs = clamped % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }

    private func focusEmoji(from name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("yoga") || lower.contains("meditat") { return "🧘‍♀️" }
        if lower.contains("water") || lower.contains("drink") { return "💧" }
        if lower.contains("walk") || lower.contains("run") || lower.contains("gym") { return "🏃" }
        if lower.contains("read") || lower.contains("book") { return "📚" }
        if lower.contains("code") || lower.contains("work") { return "💻" }
        if lower.contains("sleep") { return "😴" }
        return "⏱️"
    }

    private func resolvedSessions(
        from state: PomoAttributes.ContentState,
        fallbackName: String
    ) -> [PomoAttributes.ContentState.ParallelSession] {
        if !state.parallelSessions.isEmpty {
            return state.parallelSessions
        }
        return [
            .init(
                id: UUID(),
                focusName: fallbackName,
                remainingSeconds: state.remainingSeconds,
                startTime: state.startTime,
                endTime: state.endTime,
                isRunning: state.isRunning
            )
        ]
    }

    private func resolvedActiveSession(
        from state: PomoAttributes.ContentState,
        fallbackName: String
    ) -> PomoAttributes.ContentState.ParallelSession {
        let sessions = resolvedSessions(from: state, fallbackName: fallbackName)
        if let activeId = state.activeSessionId,
           let active = sessions.first(where: { $0.id == activeId }) {
            return active
        }
        return sessions.first!
    }
}
