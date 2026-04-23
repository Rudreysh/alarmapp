import SwiftUI

struct CountdownPresetView: View {
    @ObservedObject var store: CountdownPresetStore
    @StateObject var engine: CountdownEngine

    @StateObject private var historyStore = CountdownHistoryStore.shared
    @State private var showAddPreset = false
    @State private var showActiveTimer = false
    @State private var selectedAudience: CountdownAudience? = nil

    private var filteredPresets: [CountdownPreset] {
        store.filtered(by: selectedAudience)
    }

    private var successfulRunsThisWeek: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return historyStore.entries.filter { $0.didComplete && $0.timestamp >= weekAgo }.count
    }

    private var totalRunsThisWeek: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return historyStore.entries.filter { $0.timestamp >= weekAgo }.count
    }

    private var completionRateText: String {
        guard totalRunsThisWeek > 0 else { return "0%" }
        let value = Int((Double(successfulRunsThisWeek) / Double(totalRunsThisWeek)) * 100.0)
        return "\(value)%"
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        summaryCard

                        audienceFilterRow

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                            ForEach(filteredPresets) { preset in
                                PresetCard(preset: preset) {
                                    engine.updatePreset(preset)
                                    engine.start()
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                                        showActiveTimer = true
                                    }
                                }
                                .contextMenu {
                                    if !preset.isSystemTemplate {
                                        Button(role: .destructive) {
                                            if let index = store.presets.firstIndex(where: { $0.id == preset.id }) {
                                                withAnimation {
                                                    store.delete(at: IndexSet(integer: index))
                                                }
                                            }
                                        } label: {
                                            Label("Delete Preset", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }

                        if !historyStore.entries.isEmpty {
                            historySection
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 120)
                }

                PrimaryButton(title: "Add Custom Preset", style: .blueGlass) {
                    showAddPreset = true
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }

            if showActiveTimer {
                ActiveCountdownOverlay(engine: engine) {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        showActiveTimer = false
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(10)
            }
        }
        .sheet(isPresented: $showAddPreset) {
            AddCountdownPresetView(store: store)
        }
    }

    private var summaryCard: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Countdown")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(Colors.textPrimary)

                Text("Sports, gym, study, classroom, and focus presets")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 10)

            VStack(alignment: .trailing, spacing: 4) {
                Text(completionRateText)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(TimerPalette.accent)
                Text("This Week")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Colors.textTertiary)
            }
        }
        .padding(16)
        .timerGlassCard(cornerRadius: 18)
    }

    private var audienceFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                audienceChip(title: "All", icon: "square.grid.2x2.fill", isSelected: selectedAudience == nil) {
                    selectedAudience = nil
                }

                ForEach(CountdownAudience.allCases) { audience in
                    audienceChip(title: audience.title, icon: audience.icon, isSelected: selectedAudience == audience) {
                        selectedAudience = audience
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func audienceChip(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(isSelected ? Colors.textPrimary : Colors.textSecondary)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                Capsule()
                    .fill(isSelected ? TimerPalette.accent.opacity(0.22) : Colors.cardSurface)
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? TimerPalette.accent.opacity(0.55) : Colors.cardStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Sessions")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Colors.textPrimary)

            VStack(spacing: 0) {
                ForEach(Array(historyStore.entries.prefix(5)).indices, id: \.self) { index in
                    let entry = historyStore.entries[index]
                    HStack(spacing: 10) {
                        Circle()
                            .fill(entry.didComplete ? TimerPalette.accent.opacity(0.22) : Colors.textTertiary.opacity(0.18))
                            .frame(width: 26, height: 26)
                            .overlay(
                                Image(systemName: entry.didComplete ? "checkmark" : "xmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(entry.didComplete ? TimerPalette.accent : Colors.textSecondary)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.presetName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Colors.textPrimary)
                            Text("\(formatDuration(entry.totalDuration)) • \(entry.completedCycles) cycle(s)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Colors.textSecondary)
                        }

                        Spacer()

                        Text(entry.timestamp, style: .time)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Colors.textTertiary)
                    }
                    .padding(.vertical, 10)

                    if index < min(4, historyStore.entries.count - 1) {
                        Divider().background(Colors.cardStroke)
                    }
                }
            }
            .padding(.horizontal, 12)
            .timerGlassCard(cornerRadius: 16)
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60

        if h > 0 {
            return String(format: "%dh %02dm", h, m)
        }

        if m > 0 {
            return String(format: "%dm %02ds", m, s)
        }

        return "\(s)s"
    }
}

struct PresetCard: View {
    let preset: CountdownPreset
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    ZStack {
                        Circle()
                            .fill(preset.color.swiftUIColor.opacity(0.18))
                        Text(preset.emoji)
                            .font(.system(size: 22))
                    }
                    .frame(width: 44, height: 44)

                    Spacer()

                    if preset.autoRepeat {
                        Image(systemName: "repeat")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(TimerPalette.accent)
                            .padding(.top, 2)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(preset.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                        .lineLimit(1)

                    Text(durationLabel)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Colors.textSecondary)

                    if !preset.details.isEmpty {
                        Text(preset.details)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Colors.textTertiary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(12)
            .timerGlassCard(cornerRadius: 16)
        }
        .buttonStyle(PressedScaleButtonStyle())
    }

    private var durationLabel: String {
        let duration = formatDuration(preset.duration)
        guard preset.autoRepeat else { return duration }
        let repeats = preset.repeatCount == 0 ? "∞" : "\(preset.repeatCount)x"
        return "\(duration) • \(repeats)"
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let total = Int(max(1, seconds))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60

        if h > 0 {
            return "\(h)h \(m)m"
        }

        if m > 0 {
            return "\(m)m \(s)s"
        }

        return "\(s)s"
    }
}

struct ActiveCountdownOverlay: View {
    @ObservedObject var engine: CountdownEngine
    var onDismiss: () -> Void

    @State private var showEditSheet = false

    private var countdownWarning: String {
        let sec = Int(ceil(engine.remaining))
        guard engine.state == .running, sec > 0, sec <= 10 else { return "" }
        return "Final \(sec)s"
    }

    var body: some View {
        ZStack {
            TimerGlassBackground()

            VStack(spacing: 20) {
                HStack {
                    Button(action: onDismiss) {
                        Image(systemName: "chevron.down.circle.fill")
                            .font(.system(size: 27))
                            .foregroundColor(Colors.textSecondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        Text(engine.preset.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Colors.textPrimary)
                        Text("Round \(engine.totalRoundsText)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Colors.textSecondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Spacer()

                ZStack {
                    ProgressRing(
                        progress: max(0.0, min(1.0, engine.remaining / max(1.0, engine.preset.duration))),
                        color: TimerPalette.accent,
                        showTicks: false
                    )
                    .frame(width: 260, height: 260)

                    VStack(spacing: 8) {
                        Text(swFormatTime(engine.remaining, showHundredths: false))
                            .font(.system(size: 54, weight: .bold, design: .monospaced))
                            .foregroundColor(Colors.textPrimary)
                            .onTapGesture {
                                if engine.state == .running || engine.state == .paused {
                                    showEditSheet = true
                                }
                            }

                        if !countdownWarning.isEmpty {
                            Text(countdownWarning)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(TimerPalette.accent)
                                .transition(.opacity)
                        } else {
                            Text("\(Int(engine.progress * 100))%")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Colors.textTertiary)
                        }
                    }
                }

                HStack(spacing: 10) {
                    quickAdjustButton(title: "-10s") { engine.subtractSeconds(10) }
                    quickAdjustButton(title: "+10s") { engine.addSeconds(10) }
                    quickAdjustButton(title: "+1m") { engine.addSeconds(60) }
                }
                .padding(.horizontal, 24)

                HStack(spacing: 36) {
                    iconAction(systemName: "arrow.counterclockwise", size: 56) {
                        engine.reset()
                    }

                    Button(action: {
                        if engine.state == .running {
                            engine.pause()
                        } else {
                            engine.start()
                        }
                    }) {
                        Image(systemName: engine.state == .running ? "pause.fill" : "play.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 78, height: 78)
                            .background(Circle().fill(TimerPalette.accent))
                            .shadow(color: TimerPalette.accent.opacity(0.5), radius: 14, y: 6)
                    }

                    iconAction(systemName: "xmark", size: 56) {
                        engine.reset()
                        onDismiss()
                    }
                }
                .padding(.bottom, 44)
            }
        }
        .sheet(isPresented: $showEditSheet) {
            TimerDurationPickerView(
                initialTotalSeconds: Int(engine.remaining),
                segmentTitle: engine.preset.name,
                onSave: { seconds in
                    engine.adjustRemainingTime(to: seconds)
                }
            )
            .presentationDetents([.fraction(0.42)])
        }
    }

    private func quickAdjustButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Colors.textPrimary)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    Capsule()
                        .fill(Colors.cardSurface)
                )
                .overlay(
                    Capsule()
                        .stroke(Colors.cardStroke, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func iconAction(systemName: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 19, weight: .bold))
                .foregroundColor(Colors.textPrimary)
                .frame(width: size, height: size)
                .background(Circle().fill(Colors.cardSurface))
                .overlay(Circle().stroke(Colors.cardStroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
