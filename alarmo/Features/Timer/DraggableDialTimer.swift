import SwiftUI
import AudioToolbox

struct DraggableDialTimer: View {
    @Binding var totalSeconds: Int
    var isRunning: Bool
    var progress: Double // Used when running, 0 to 1
    var color: Color
    var maxSeconds: Int = 180 * 60 // 3 hours max

    @State private var isDragging: Bool = false
    
    private var accentSunYellow: Color {
        Color(red: 0.98, green: 0.84, blue: 0.30)
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

            let dialSize = size * 0.92
            let innerRadius = radius * 0.70
            let currentTickIndex = Int(round(ringFraction * 60)) % 60

            ZStack {
                // Sunray-style ambient ring glow.
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [
                                Colors.accentBlue.opacity(isDragging ? 0.14 : 0.10),
                                color.opacity(isDragging ? 0.20 : 0.14),
                                accentSunYellow.opacity(isDragging ? 0.12 : 0.08),
                                Colors.accentBlue.opacity(isDragging ? 0.14 : 0.10)
                            ],
                            center: .center
                        ),
                        lineWidth: 8
                    )
                    .blur(radius: 6)
                    .frame(width: dialSize + 14, height: dialSize + 14)

                Circle()
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    .frame(width: dialSize, height: dialSize)

                // Sunray ticks around the dial.
                ForEach(0..<60) { i in
                    let isStep = i % 5 == 0
                    let tickFraction = Double(i) / 60.0
                    let isActive = tickFraction <= (ringFraction + 0.005)
                    let isHead = i == currentTickIndex && ringFraction > 0

                    Capsule()
                        .fill(isActive ? color : Color.white.opacity(isStep ? 0.30 : 0.10))
                        .frame(
                            width: isHead ? 3.5 : (isStep ? 2.2 : 1.1),
                            height: isHead ? size * 0.073 : (isStep ? size * 0.050 : size * 0.028)
                        )
                        .offset(y: -(dialSize / 2))
                        .rotationEffect(.degrees(Double(i) * 6))
                        .shadow(
                            color: isHead ? color.opacity(0.8) : (isActive ? color.opacity(0.5) : .clear),
                            radius: isHead ? 8 : 4
                        )
                        .scaleEffect(isHead ? 1.12 : 1.0)
                        .animation(.spring(response: 0.26, dampingFraction: 0.8), value: ringFraction)
                }

                // Active outer ring like alarm editor style.
                Circle()
                    .trim(from: 0.0, to: ringFraction)
                    .stroke(
                        AngularGradient(
                            colors: [
                                Colors.accentBlue.opacity(0.45),
                                color,
                                accentSunYellow.opacity(0.74),
                                Colors.accentBlue.opacity(0.70)
                            ],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360 * ringFraction)
                        ),
                        style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                    )
                    .frame(width: dialSize + 10, height: dialSize + 10)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: color.opacity(0.4), radius: 6)
                    .animation(.interactiveSpring(response: 0.24, dampingFraction: 0.86), value: ringFraction)

                // Glass-like center to match alarm dial style.
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.05), Color.black.opacity(0.22)],
                            center: .center,
                            startRadius: 10,
                            endRadius: innerRadius
                        )
                    )
                    .frame(width: innerRadius * 2, height: innerRadius * 2)
                    .overlay(
                        Circle()
                            .stroke(color.opacity(0.28), lineWidth: 1)
                    )

                // Keep pointer movement behavior unchanged (visual only restyled).
                if !isRunning {
                    let handAngle = Angle.degrees(ringFraction * 360)

                    ZStack {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.96),
                                        color.opacity(0.92),
                                        accentSunYellow.opacity(0.68)
                                    ],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .frame(width: 3, height: innerRadius)
                            .offset(y: -innerRadius / 2)
                            .shadow(color: .white.opacity(0.8), radius: 4)

                        Circle()
                            .fill(Color.white)
                            .frame(width: 14, height: 14)
                            .shadow(color: .white.opacity(0.8), radius: 4)
                    }
                    .rotationEffect(handAngle)
                }

                if completedHours > 0 {
                    Text("\(completedHours)h")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(Colors.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                        .offset(y: -size * 0.23)
                }
            }
            .frame(width: size, height: size)
            .position(x: center.x, y: center.y)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if isRunning { return }
                        isDragging = true
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
}
