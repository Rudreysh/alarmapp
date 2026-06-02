import ActivityKit
import WidgetKit
import SwiftUI

@main
struct AwaykWidgetBundle: WidgetBundle {
    var body: some Widget {
        AwaykWidgetLiveActivity()
    }
}

struct AwaykWidgetLiveActivity: Widget {
    private enum RowDensity {
        case regular
        case compact
    }

    private enum LockScreenLayout {
        static let containerInset: CGFloat = 10
        static let expandedTopInset: CGFloat = 10
        static let expandedBottomInset: CGFloat = 8
        static let collapsedVerticalInset: CGFloat = 12
        static let sectionSpacing: CGFloat = 4
        static let collapseControlTopSpacing: CGFloat = 2
        static let rowVerticalPaddingRegular: CGFloat = 5
        static let rowVerticalPaddingCompact: CGFloat = 2
        static let previewBadgeSize: CGFloat = 42
        static let maxExpandedRows: Int = 2
    }

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PomoAttributes.self) { context in
            let sessions = resolvedSessions(from: context.state, fallbackName: context.attributes.focusName)
            let active = resolvedActiveSession(from: context.state, sessions: sessions)
            let isExpanded = context.state.isExpanded || sessions.count <= 1
            let showsAmbientRow = context.state.isAmbientPlaying &&
                (context.state.ambientSoundName?.isEmpty == false)

            VStack(spacing: LockScreenLayout.sectionSpacing) {
                if showsAmbientRow,
                   let ambient = context.state.ambientSoundName {
                    lockScreenAmbientRow(ambient: ambient)
                }

                if isExpanded {
                    expandedLockScreenContent(sessions: sessions, active: active)
                } else {
                    collapsedStackRow(sessions: sessions, active: active)
                }
            }
            .background(Color.clear)
            .padding(.horizontal, LockScreenLayout.containerInset)
            .padding(
                .top,
                isExpanded ? LockScreenLayout.expandedTopInset : LockScreenLayout.collapsedVerticalInset
            )
            .padding(
                .bottom,
                isExpanded ? LockScreenLayout.expandedBottomInset : LockScreenLayout.collapsedVerticalInset
            )
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .widgetURL(nil)
        } dynamicIsland: { context in
            let sessions = resolvedSessions(from: context.state, fallbackName: context.attributes.focusName)
            let active = resolvedActiveSession(from: context.state, sessions: sessions)

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
                    Button(intent: TogglePomoRunStateIntent(sessionId: active.id.uuidString)) {
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

    @ViewBuilder
    private func expandedLockScreenContent(
        sessions: [PomoAttributes.ContentState.ParallelSession],
        active: PomoAttributes.ContentState.ParallelSession
    ) -> some View {
        ViewThatFits(in: .vertical) {
            expandedSessionList(
                sessions: sessions,
                density: .regular,
                showsCollapse: sessions.count > 1
            )

            expandedSessionList(
                sessions: sessions,
                density: .compact,
                showsCollapse: sessions.count > 1
            )

            collapsedStackRow(sessions: sessions, active: active)
        }
    }

    @ViewBuilder
    private func expandedSessionList(
        sessions: [PomoAttributes.ContentState.ParallelSession],
        density: RowDensity,
        showsCollapse: Bool
    ) -> some View {
        let visibleSessions = Array(sessions.prefix(LockScreenLayout.maxExpandedRows))

        VStack(spacing: density == .regular ? 4 : 3) {
            ForEach(visibleSessions, id: \.id) { session in
                lockScreenSessionRow(session: session, density: density)
            }

            if showsCollapse {
                Button(intent: TogglePomoExpandedIntent()) {
                    Text("Show less")
                        .font(.system(size: density == .regular ? 11 : 10, weight: .semibold))
                        .foregroundColor(.black.opacity(0.55))
                }
                .buttonStyle(.plain)
                .padding(.top, LockScreenLayout.collapseControlTopSpacing)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.clear)
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
    private func collapsedStackRow(
        sessions: [PomoAttributes.ContentState.ParallelSession],
        active: PomoAttributes.ContentState.ParallelSession
    ) -> some View {
        Button(intent: TogglePomoExpandedIntent()) {
            HStack(spacing: 12) {
                collapsedStackPreview(session: active)
                collapsedStackDescription(sessions: sessions, active: active)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(8)
                    .background(Circle().fill(Color.white.opacity(0.12)))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(0.72))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func collapsedStackDescription(
        sessions: [PomoAttributes.ContentState.ParallelSession],
        active: PomoAttributes.ContentState.ParallelSession
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(active.focusName)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
            timerText(
                startTime: active.startTime,
                endTime: active.endTime,
                remainingSeconds: active.remainingSeconds,
                isRunning: active.isRunning,
                size: 16,
                color: .white,
                width: nil
            )
            Text("\(sessions.count) running • tap to expand")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func collapsedStackPreview(
        session: PomoAttributes.ContentState.ParallelSession
    ) -> some View {
        collapsedStackPreviewBadge(session: session)
            .frame(width: LockScreenLayout.previewBadgeSize, height: LockScreenLayout.previewBadgeSize)
    }

    @ViewBuilder
    private func collapsedStackPreviewBadge(
        session: PomoAttributes.ContentState.ParallelSession
    ) -> some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.24))
                .frame(width: LockScreenLayout.previewBadgeSize, height: LockScreenLayout.previewBadgeSize)

            Circle()
                .stroke(Color.white.opacity(0.20), lineWidth: 4)
                .frame(width: LockScreenLayout.previewBadgeSize, height: LockScreenLayout.previewBadgeSize)

            LockScreenProgressRing(
                startTime: session.startTime,
                endTime: session.endTime,
                remainingSeconds: session.remainingSeconds,
                isRunning: session.isRunning,
                diameter: LockScreenLayout.previewBadgeSize,
                lineWidth: 4
            )

            Text(focusEmoji(from: session.focusName))
                .font(.system(size: 17))
        }
        .frame(width: LockScreenLayout.previewBadgeSize, height: LockScreenLayout.previewBadgeSize)
    }

    @ViewBuilder
    private func lockScreenSessionRow(
        session: PomoAttributes.ContentState.ParallelSession,
        density: RowDensity = .regular
    ) -> some View {
        let badgeSize: CGFloat = density == .regular ? 44 : 36
        let ringLineWidth: CGFloat = density == .regular ? 4 : 3
        let titleSize: CGFloat = density == .regular ? 13 : 12
        let timeSize: CGFloat = density == .regular ? 13 : 12
        let emojiSize: CGFloat = density == .regular ? 18 : 15
        let buttonSize: CGFloat = density == .regular ? 30 : 26
        let buttonIconSize: CGFloat = density == .regular ? 14 : 12
        let rowVerticalPadding: CGFloat = density == .regular
            ? LockScreenLayout.rowVerticalPaddingRegular
            : LockScreenLayout.rowVerticalPaddingCompact

        HStack(spacing: density == .regular ? 10 : 8) {
            Button(intent: OpenPomodoroSessionIntent(sessionId: session.id.uuidString)) {
                HStack(spacing: density == .regular ? 10 : 8) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.24))
                            .frame(width: badgeSize, height: badgeSize)

                        Circle()
                            .stroke(Color.white.opacity(0.20), lineWidth: ringLineWidth)
                            .frame(width: badgeSize, height: badgeSize)

                        LockScreenProgressRing(
                            startTime: session.startTime,
                            endTime: session.endTime,
                            remainingSeconds: session.remainingSeconds,
                            isRunning: session.isRunning,
                            diameter: badgeSize,
                            lineWidth: ringLineWidth
                        )

                        Text(focusEmoji(from: session.focusName))
                            .font(.system(size: emojiSize))
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(session.focusName)
                            .font(.system(size: titleSize, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        timerText(
                            startTime: session.startTime,
                            endTime: session.endTime,
                            remainingSeconds: session.remainingSeconds,
                            isRunning: session.isRunning,
                            size: timeSize,
                            color: .white,
                            width: nil
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer(minLength: 6)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(intent: TogglePomoRunStateIntent(sessionId: session.id.uuidString)) {
                Image(systemName: session.isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: buttonIconSize, weight: .semibold))
                    .foregroundColor(.black.opacity(0.88))
                    .frame(width: buttonSize, height: buttonSize)
                    .background(Circle().fill(Color.white))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, rowVerticalPadding)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func lockScreenAmbientRow(ambient: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "music.note")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.88))

            Text(ambient)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.88))
                .lineLimit(1)

            Spacer(minLength: 8)

            Button(intent: ToggleAmbientPlaybackIntent()) {
                Image(systemName: "pause.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.black.opacity(0.88))
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.white))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.50))
        )
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
        let live = state.parallelSessions.filter { $0.isRunning || $0.remainingSeconds > 0 }
        if !live.isEmpty { return live }

        return [
            .init(
                id: state.activeSessionId ?? UUID(),
                focusName: fallbackName,
                remainingSeconds: max(0, state.remainingSeconds),
                startTime: state.startTime,
                endTime: state.endTime,
                isRunning: state.isRunning
            )
        ]
    }

    private func resolvedActiveSession(
        from state: PomoAttributes.ContentState,
        sessions: [PomoAttributes.ContentState.ParallelSession]
    ) -> PomoAttributes.ContentState.ParallelSession {
        if let activeId = state.activeSessionId,
           let active = sessions.first(where: { $0.id == activeId }) {
            return active
        }
        return sessions.first!
    }
}
