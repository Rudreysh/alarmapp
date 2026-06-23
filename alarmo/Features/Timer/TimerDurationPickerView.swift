import SwiftUI

/// Opal-style duration picker: quick presets plus a horizontal ruler you scrub
/// left/right (right increases, left decreases) to pick hours + minutes. Same API as
/// before (`initialTotalSeconds` / `onSave(seconds)`), so callers are unchanged.
struct TimerDurationPickerView: View {
    let initialTotalSeconds: Int
    let segmentTitle: String
    let onSave: (Int) -> Void

    @Environment(\.dismiss) var dismiss

    @State private var minutes: Int
    @GestureState private var dragTranslation: CGFloat = 0

    private let minMinutes = 1
    private let maxMinutes = 480          // 8h
    private let pointsPerMinute: CGFloat = 3.2   // scrub sensitivity
    private let snap = 5                   // snap to 5-minute steps while scrubbing
    private let presets: [(String, Int)] = [
        ("15m", 15),
        ("30m", 30),
        ("45m", 45),
        ("1h", 60),
        ("2h", 120),
        ("4h", 240),
        ("8h", 480)
    ]

    init(initialTotalSeconds: Int, segmentTitle: String, onSave: @escaping (Int) -> Void) {
        self.initialTotalSeconds = initialTotalSeconds
        self.segmentTitle = segmentTitle
        self.onSave = onSave
        self._minutes = State(initialValue: max(1, initialTotalSeconds / 60))
    }

    /// Live value including the in-progress drag (snapped to 5 min).
    private var previewMinutes: Int { clamped(from: dragTranslation) }

    private func clamped(from translation: CGFloat) -> Int {
        let rawDelta = translation / pointsPerMinute
        let snappedDelta = (rawDelta / CGFloat(snap)).rounded() * CGFloat(snap)
        return max(minMinutes, min(maxMinutes, minutes + Int(snappedDelta)))
    }

    private func label(_ m: Int) -> String {
        let h = m / 60, mm = m % 60
        if h > 0 && mm > 0 { return "\(h)h \(mm)m" }
        if h > 0 { return "\(h)h" }
        return "\(mm)m"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                TimerGlassBackground()

                VStack(spacing: 26) {
                    Text(segmentTitle.uppercased())
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Colors.textTertiary)
                        .kerning(1.5)
                        .padding(.top, 20)

                    // Presets
                    HStack(spacing: 8) {
                        ForEach(presets, id: \.1) { preset in
                            presetChip(preset.0, preset.1)
                        }
                    }
                    .padding(.horizontal, 16)

                    // Big readout
                    Text(label(previewMinutes))
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundColor(TimerPalette.accent)
                        .contentTransition(.numericText())
                        .animation(.snappy(duration: 0.15), value: previewMinutes)

                    // Ruler scrubber
                    ruler

                    Text("Slide to adjust • right = more, left = less")
                        .font(.system(size: 12))
                        .foregroundColor(Colors.textTertiary)

                    Spacer()
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Colors.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onSave(max(60, previewMinutes * 60))
                        dismiss()
                    }
                    .foregroundColor(TimerPalette.accent)
                    .fontWeight(.bold)
                }
            }
        }
    }

    private var ruler: some View {
        GeometryReader { geo in
            ZStack {
                Canvas { ctx, size in
                    let centerX = size.width / 2
                    let baseOffset = centerX - CGFloat(previewMinutes) * pointsPerMinute
                    var m = 0
                    while m <= maxMinutes {
                        let x = baseOffset + CGFloat(m) * pointsPerMinute
                        if x >= -24 && x <= size.width + 24 {
                            let major = m % 30 == 0
                            let h: CGFloat = major ? 26 : 13
                            var path = Path()
                            path.move(to: CGPoint(x: x, y: size.height / 2 - h / 2))
                            path.addLine(to: CGPoint(x: x, y: size.height / 2 + h / 2))
                            ctx.stroke(
                                path,
                                with: .color(.white.opacity(major ? 0.55 : 0.22)),
                                lineWidth: major ? 2 : 1
                            )
                        }
                        m += 5
                    }
                }

                // Fixed center needle
                Rectangle()
                    .fill(TimerPalette.accent)
                    .frame(width: 3, height: 40)
                    .clipShape(Capsule())
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .updating($dragTranslation) { value, state, _ in
                        state = value.translation.width
                    }
                    .onEnded { value in
                        minutes = clamped(from: value.translation.width)
                    }
            )
        }
        .frame(height: 72)
        .padding(.horizontal, 20)
        .clipped()
    }

    private func presetChip(_ title: String, _ m: Int) -> some View {
        let selected = previewMinutes == m
        return Button { minutes = m } label: {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(selected ? .black : Colors.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    Capsule().fill(selected ? TimerPalette.accent : Color.white.opacity(0.10))
                )
        }
        .buttonStyle(.plain)
    }
}
