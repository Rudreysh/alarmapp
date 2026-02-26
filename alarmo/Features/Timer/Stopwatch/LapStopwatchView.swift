import SwiftUI

// MARK: - Main Stopwatch View with Lap/Split Tracking

struct LapStopwatchView: View {
    @ObservedObject var engine: StopwatchEngine
    @State private var showTargetSheet = false
    @State private var targetMinutes: String = ""
    @State private var alertEveryMinutes: String = ""
    @State private var selectedMode: StopwatchRecordMode = .lap
    @State private var isExporting = false

    var diameter: CGFloat {
        min(UIScreen.main.bounds.width * 0.72, 280)
    }

    var body: some View {
        VStack(spacing: 0) {

            // MARK: Mode Toggle (Lap / Split)
            HStack(spacing: 0) {
                ForEach([("Lap", StopwatchRecordMode.lap), ("Split", .split)], id: \.0) { label, mode in
                    Button {
                        withAnimation(.spring(response: 0.25)) { selectedMode = mode }
                        engine.recordMode = mode
                    } label: {
                        Text(label)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(selectedMode == mode ? .black : Colors.textSecondary)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity)
                            .background(
                                selectedMode == mode
                                    ? Capsule().fill(TimerPalette.accent)
                                    : Capsule().fill(Color.clear)
                            )
                    }
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(red: 0.10, green: 0.12, blue: 0.16))
            )
            .padding(.horizontal, 60)
            .padding(.top, 8)

            // MARK: Ring + Time Display
            ZStack {
                ProgressRing(progress: engine.elapsed.truncatingRemainder(dividingBy: 60) / 60,
                             color: TimerPalette.accent, showTicks: true)
                    .frame(width: diameter, height: diameter)
                    .animation(.linear(duration: 0.01), value: engine.elapsed)

                VStack(spacing: 6) {
                    // Current lap time (small, above main)
                    if engine.state != .idle {
                        Text(swFormatTime(engine.currentLapTime, showHundredths: true))
                            .font(.system(size: 18, weight: .medium, design: .monospaced))
                            .foregroundColor(TimerPalette.accent.opacity(0.8))
                    }

                    Text(swFormatTime(engine.elapsed, showHundredths: engine.state != .idle))
                        .font(.system(size: diameter * 0.18, weight: .regular, design: .monospaced))
                        .kerning(1.5)
                        .foregroundColor(Colors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .contentTransition(.numericText())

                    // Lap count badge
                    if !engine.laps.isEmpty {
                        Text("Lap \(engine.laps.count + 1)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Colors.textSecondary)
                    }
                }
            }
            .padding(.top, 8)

            Spacer(minLength: 4)

            // MARK: Controls
            HStack(spacing: 44) {
                // Lap / Reset
                circleButton(
                    icon: engine.state == .idle ? "arrow.counterclockwise" : "flag.fill",
                    color: engine.state == .idle ? Colors.textSecondary : TimerPalette.accentSoft,
                    size: 56
                ) {
                    if engine.state == .idle {
                        // No-op (reset already done on stop)
                    } else {
                        engine.recordLap()
                    }
                }
                .disabled(engine.state == .idle)
                .opacity(engine.state == .idle ? 0.35 : 1)

                // Play / Pause / Resume
                Button {
                    switch engine.state {
                    case .idle: engine.start()
                    case .running: engine.pause()
                    case .paused: engine.resume()
                    }
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    ZStack {
                        Circle()
                            .fill(TimerPalette.accent)
                            .frame(width: 72, height: 72)
                        Image(systemName: engine.state == .running ? "pause.fill" : "play.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.black)
                    }
                    .shadow(color: TimerPalette.accent.opacity(0.5), radius: 16, y: 6)
                }

                // Stop
                circleButton(icon: "stop.fill",
                             color: engine.state == .idle ? Colors.textSecondary : Color(red: 0.9, green: 0.25, blue: 0.25),
                             size: 56) {
                    engine.stop()
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                }
                .disabled(engine.state == .idle)
                .opacity(engine.state == .idle ? 0.35 : 1)
            }
            .padding(.bottom, 12)

            // MARK: Target Alert Pill
            Button {
                showTargetSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: engine.targetTime != nil || engine.alertInterval != nil
                          ? "bell.fill" : "bell")
                        .font(.system(size: 12))
                    Text(alertPillText)
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(engine.targetTime != nil || engine.alertInterval != nil
                                 ? TimerPalette.accent : Colors.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color(red: 0.10, green: 0.12, blue: 0.16))
                )
            }
            .padding(.bottom, 8)

            // MARK: Lap List
            if !engine.laps.isEmpty {
                Divider().background(Color.white.opacity(0.07)).padding(.bottom, 4)

                // Header
                HStack {
                    Text(selectedMode == .lap ? "LAP" : "SPLIT")
                    Spacer()
                    Text(selectedMode == .lap ? "LAP TIME" : "CUMULATIVE")
                    Spacer()
                    Text("TOTAL")
                }
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Colors.textTertiary)
                .padding(.horizontal, 20)

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(engine.laps) { lap in
                            lapRow(lap)
                        }
                    }
                }
                .frame(maxHeight: 220)
            }
        }
        .sheet(isPresented: $showTargetSheet) {
            targetAlertSheet
        }
    }

    // MARK: - Lap Row
    @ViewBuilder
    private func lapRow(_ lap: LapEntry) -> some View {
        let isBest = engine.bestLap?.id == lap.id && engine.laps.count >= 2
        let isWorst = engine.worstLap?.id == lap.id && engine.laps.count >= 2
        let displayTime = selectedMode == .lap ? lap.lapTime : lap.totalTime
        let accentColor: Color = isBest ? Color(red: 0.20, green: 0.78, blue: 0.45)
                               : isWorst ? Color(red: 0.90, green: 0.25, blue: 0.25)
                               : Colors.textPrimary

        HStack {
            Text("Lap \(lap.number)")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(accentColor)
                .frame(width: 60, alignment: .leading)

            Spacer()

            Text(swFormatTime(displayTime, showHundredths: true))
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundColor(accentColor)
            Spacer()

            Text(swFormatTime(lap.totalTime, showHundredths: true))
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .foregroundColor(Colors.textSecondary)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 9)
        .background(isBest ? Color(red: 0.20, green: 0.78, blue: 0.45).opacity(0.05) :
                    isWorst ? Color(red: 0.90, green: 0.25, blue: 0.25).opacity(0.05) :
                    Color.clear)
    }

    // MARK: - Target Alert Sheet
    private var targetAlertSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Set Pace Alerts")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Colors.textPrimary)

                // Target time
                VStack(alignment: .leading, spacing: 8) {
                    Label("Alert at target time", systemImage: "stopwatch")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Colors.textSecondary)
                    HStack {
                        TextField("Minutes (e.g. 10)", text: $targetMinutes)
                            .keyboardType(.numberPad)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Colors.textPrimary)
                        Text("min")
                            .foregroundColor(Colors.textSecondary)
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(red: 0.10, green: 0.12, blue: 0.16)))
                }

                // Interval alert
                VStack(alignment: .leading, spacing: 8) {
                    Label("Alert every N minutes", systemImage: "bell.badge.waveform")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Colors.textSecondary)
                    HStack {
                        TextField("e.g. 5", text: $alertEveryMinutes)
                            .keyboardType(.numberPad)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Colors.textPrimary)
                        Text("min")
                            .foregroundColor(Colors.textSecondary)
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(red: 0.10, green: 0.12, blue: 0.16)))
                }

                // Clear button
                Button("Clear Alerts") {
                    engine.targetTime = nil
                    engine.alertInterval = nil
                    targetMinutes = ""
                    alertEveryMinutes = ""
                }
                .foregroundColor(Color(red: 0.9, green: 0.25, blue: 0.25))

                Spacer()
            }
            .padding()
            .background(Color(red: 0.05, green: 0.06, blue: 0.09).ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Set") {
                        if let m = Double(targetMinutes), m > 0 {
                            engine.targetTime = m * 60
                        }
                        if let m = Double(alertEveryMinutes), m > 0 {
                            engine.alertInterval = m * 60
                        }
                        showTargetSheet = false
                    }
                    .foregroundColor(TimerPalette.accent)
                    .fontWeight(.bold)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showTargetSheet = false }
                        .foregroundColor(Colors.textSecondary)
                }
            }
        }
        .presentationDetents([.medium])
        .preferredColorScheme(.dark)
    }

    private var alertPillText: String {
        var parts: [String] = []
        if let t = engine.targetTime { parts.append("Target: \(Int(t/60))m") }
        if let i = engine.alertInterval { parts.append("Every: \(Int(i/60))m") }
        return parts.isEmpty ? "Set Pace Alert" : parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func circleButton(icon: String, color: Color, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.36, weight: .semibold))
                .foregroundColor(color)
                .frame(width: size, height: size)
                .background(Circle().fill(Color(red: 0.13, green: 0.15, blue: 0.20)))
                .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
