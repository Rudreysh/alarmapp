import SwiftUI
import AudioToolbox

struct DraggableDialTimer: View {
    @Binding var totalSeconds: Int
    var isRunning: Bool
    var progress: Double // Used when running, 0 to 1
    var color: Color
    var centerSymbol: String = "timer"
    var particleSeed: String = "focus"
    var maxSeconds: Int = 180 * 60 // 3 hours max
    var onCenterTap: (() -> Void)? = nil

    @State private var isDragging: Bool = false
    @State private var lastDragUpdateTime: TimeInterval = 0
    
    private var accentSunYellow: Color {
        Color(red: 0.98, green: 0.84, blue: 0.30)
    }

    private var centerAccentColor: Color {
        semanticColor(for: centerSymbol) ?? color
    }

    private var totalMinutes: Int {
        max(0, totalSeconds / 60)
    }

    private var remainderMinutes: Int {
        totalMinutes % 60
    }

    private var completedHours: Int {
        totalMinutes / 60
    }

    // For full-hour values in idle mode, render a full ring like the alarm sunray dial.
    private var ringFraction: Double {
        if isRunning {
            return min(max(progress, 0), 1)
        }
        if totalMinutes > 0 && remainderMinutes == 0 {
            return 1
        }
        return Double(remainderMinutes) / 60.0
    }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let radius = size / 2
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let trackWidth = size * 0.16
            let ringRadius = (size - trackWidth) / 2
            let innerDiameter = size * 0.512 // 20% smaller than previous center circle
            let logoBadgeDiameter = size * 0.352
            let knobAngle = Angle.degrees((ringFraction * 360) - 90)

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.18), style: StrokeStyle(lineWidth: trackWidth, lineCap: .round))
                    .frame(width: size, height: size)

                Circle()
                    .trim(from: 0.0, to: ringFraction)
                    .stroke(
                        AngularGradient(
                            colors: [
                                color.opacity(0.60),
                                color,
                                accentSunYellow.opacity(0.72),
                                color.opacity(0.70)
                            ],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360 * ringFraction)
                        ),
                        style: StrokeStyle(lineWidth: trackWidth, lineCap: .round)
                    )
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: color.opacity(0.45), radius: 10, x: 0, y: 4)
                    .animation(.interactiveSpring(response: 0.20, dampingFraction: 0.84), value: ringFraction)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                centerAccentColor.opacity(0.28),
                                centerAccentColor.opacity(0.14),
                                Color.white.opacity(0.07)
                            ],
                            center: .center,
                            startRadius: innerDiameter * 0.04,
                            endRadius: innerDiameter * 0.62
                        )
                    )
                    .frame(width: innerDiameter, height: innerDiameter)
                    .overlay(
                        Circle()
                            .stroke(centerAccentColor.opacity(0.32), lineWidth: 1.2)
                    )

                centerSymbolView(logoBadgeDiameter: logoBadgeDiameter)
                    .contentShape(Circle())
                    .onTapGesture {
                        onCenterTap?()
                    }

                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
                    let now = timeline.date.timeIntervalSinceReferenceDate
                    let isActivelyMoving = isDragging && (now - lastDragUpdateTime) < 0.12
                    if isActivelyMoving && ringFraction > 0.001 {
                        let startAngle = -Double.pi / 2
                        let sweep = (Double.pi * 2) * ringFraction

                        ForEach(0..<18, id: \.self) { i in
                            let seed = seededValue(index: i, salt: 91)
                            let speed = 0.22 + seededValue(index: i, salt: 17) * 0.58
                            let direction = seededValue(index: i, salt: 33) > 0.5 ? 1.0 : -1.0
                            // Keep particles constrained to the progressed arc only.
                            let arcPosition = seededValue(index: i, salt: 71)
                            let baseAngle = startAngle + (arcPosition * sweep)
                            let angle = baseAngle + direction * now * speed * 0.08

                            // Keep particles on donut surface (within ring thickness), not in background.
                            let radialJitter = (seededValue(index: i, salt: 63) - 0.5) * (trackWidth * 0.70)
                            let offsetRadius = ringRadius + radialJitter
                            let x = cos(angle) * offsetRadius
                            let y = sin(angle) * offsetRadius
                            let alpha = 0.82 * (0.35 + seed * 0.65)
                            let size = 2.0 + seededValue(index: i, salt: 49) * 7.0

                            Group {
                                if i % 3 == 0 {
                                    Capsule(style: .circular)
                                        .fill(color.opacity(alpha))
                                        .frame(width: size * 2.1, height: size * 0.72)
                                        .rotationEffect(.degrees((angle * 180 / .pi) + 90))
                                } else {
                                    Circle()
                                        .fill((i % 2 == 0 ? color : accentSunYellow).opacity(alpha))
                                        .frame(width: size, height: size)
                                }
                            }
                            .offset(x: x, y: y)
                        }
                    }
                }

                // Draggable completion knob.
                Circle()
                    .fill(color.opacity(0.95))
                    .frame(width: trackWidth * 0.86, height: trackWidth * 0.86)
                    .overlay(
                        Image(systemName: isDragging ? "arrow.left.and.right" : "arrow.down")
                            .font(.system(size: trackWidth * 0.30, weight: .bold))
                            .foregroundColor(.black.opacity(0.55))
                    )
                    .offset(x: cos(knobAngle.radians) * ringRadius, y: sin(knobAngle.radians) * ringRadius)
                    .shadow(color: color.opacity(0.48), radius: 8, x: 0, y: 4)
                    .animation(.interactiveSpring(response: 0.18, dampingFraction: 0.82), value: ringFraction)
            }
            .frame(width: size, height: size)
            .position(x: center.x, y: center.y)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if isRunning { return }
                        let dx = value.location.x - center.x
                        let dy = value.location.y - center.y
                        let distance = sqrt((dx * dx) + (dy * dy))
                        let ringBand = trackWidth * 0.92
                        guard abs(distance - ringRadius) <= ringBand else { return }
                        isDragging = true
                        lastDragUpdateTime = Date().timeIntervalSinceReferenceDate
                        handleDrag(location: value.location, center: center)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
        }
    }

    private func handleDrag(location: CGPoint, center: CGPoint) {
        let dx = location.x - center.x
        let dy = location.y - center.y

        // Calculate raw angle from 0 at top, clockwise
        var angle = atan2(dy, dx) + .pi / 2
        if angle < 0 { angle += 2 * .pi }

        let targetFraction = angle / (2 * .pi)
        var targetMinutes = Int(round(targetFraction * 60))
        if targetMinutes == 60 { targetMinutes = 0 }

        let currentTotalMinutes = totalSeconds / 60
        let currentRemMinutes = currentTotalMinutes % 60

        // Find smallest difference
        var diff = targetMinutes - currentRemMinutes
        if diff > 30 {
            diff -= 60
        } else if diff < -30 {
            diff += 60
        }

        let newTotalMinutes = currentTotalMinutes + diff
        let newTotalSeconds = newTotalMinutes * 60

        // Minimum 1 minute (60s), Maximum maxSeconds
        let clampedSeconds = max(60, min(newTotalSeconds, maxSeconds))

        if clampedSeconds != totalSeconds {
            totalSeconds = clampedSeconds
            UISelectionFeedbackGenerator().selectionChanged()
            AudioServicesPlaySystemSound(1104) // Tick sound
        }
    }

    @ViewBuilder
    private func centerSymbolView(logoBadgeDiameter: CGFloat) -> some View {
        let isEmoji = centerSymbol.allSatisfy({ !$0.isASCII })

        return ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            centerAccentColor.opacity(0.42),
                            centerAccentColor.opacity(0.24),
                            Color.black.opacity(0.22)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.20), lineWidth: 1)
                )
                .shadow(color: centerAccentColor.opacity(0.30), radius: 10, x: 0, y: 4)

            if isEmoji {
                Text(centerSymbol)
                    .font(.system(size: logoBadgeDiameter * 0.46))
            } else {
                Image(systemName: centerSymbol)
                    .font(.system(size: logoBadgeDiameter * 0.42, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(centerAccentColor.opacity(0.95))
                    .shadow(color: Color.black.opacity(0.22), radius: 4, x: 0, y: 2)
            }
        }
        .frame(width: logoBadgeDiameter, height: logoBadgeDiameter)
    }

    private func seededValue(index: Int, salt: Int) -> Double {
        let seed = particleSeed.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let raw = sin(Double(seed + (index * 73) + (salt * 31)) * 12.9898) * 43758.5453
        return raw - floor(raw)
    }

    private func semanticColor(for symbol: String) -> Color? {
        let value = symbol.lowercased()

        if value.contains("🧘") || value.contains("yoga") || value.contains("meditat") {
            return Color(red: 0.62, green: 0.55, blue: 0.98)
        }
        if value.contains("🏃") || value.contains("run") || value.contains("walk") || value.contains("figure.run") {
            return Color(red: 0.98, green: 0.48, blue: 0.23)
        }
        if value.contains("💧") || value.contains("drop") || value.contains("water") || value.contains("drink") {
            return Color(red: 0.32, green: 0.69, blue: 0.97)
        }
        if value.contains("📚") || value.contains("book") || value.contains("read") || value.contains("study") {
            return Color(red: 0.95, green: 0.67, blue: 0.24)
        }
        if value.contains("💻") || value.contains("laptop") || value.contains("code") || value.contains("work") {
            return Color(red: 0.38, green: 0.86, blue: 0.70)
        }
        if value.contains("🎓") || value.contains("learn") || value.contains("graduationcap") {
            return Color(red: 0.50, green: 0.75, blue: 1.00)
        }
        if value.contains("😴") || value.contains("sleep") || value.contains("bed") || value.contains("moon") {
            return Color(red: 0.56, green: 0.62, blue: 0.94)
        }
        if value.contains("🧠") || value.contains("brain") || value.contains("focus") || value.contains("sparkles") {
            return Color(red: 0.94, green: 0.55, blue: 0.75)
        }
        return nil
    }
}
