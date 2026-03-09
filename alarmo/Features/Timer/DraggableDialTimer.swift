import SwiftUI
import AudioToolbox

struct DraggableDialTimer: View {
    @Binding var totalSeconds: Int
    var isRunning: Bool
    var progress: Double // Used when running, 0 to 1
    var color: Color
    var maxSeconds: Int = 180 * 60 // 3 hours max

    @State private var dragAngle: Double = 0
    @State private var isDragging: Bool = false

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let radius = size / 2
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            
            // Calculate display values
            let displaySeconds = !isRunning ? totalSeconds : Int(progress * Double(totalSeconds))
            let displayMinutes = displaySeconds / 60
            let rounds = displayMinutes / 60
            let remainderMinutes = displayMinutes % 60
            
            // Calculate fractions
            // 0.0 to 1.0 (where 1.0 is full circle = 60 mins)
            let fraction = !isRunning ? Double(remainderMinutes) / 60.0 : progress
            let isFullRound = displayMinutes > 0 && remainderMinutes == 0 && !isRunning
            
            let sectorRadius = radius * 0.70
            
            ZStack {
                // 1. Ambient Background Glow
                Circle()
                    .stroke(color.opacity(0.06), lineWidth: 8)
                    .blur(radius: 6)
                    .frame(width: size * 0.92, height: size * 0.92)
                
                Circle()
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    .frame(width: size * 0.9, height: size * 0.9)

                // 2. Sun Ray Dial Ticks
                ForEach(0..<60) { i in
                    let isStep = i % 5 == 0
                    let tickFraction = Double(i) / 60.0
                    let isActive = tickFraction <= (fraction + 0.005) // Include current tick
                    
                    // "Head Tick" logic: find the closest tick to current progress
                    let currentTickIndex = Int(round(fraction * 60)) % 60
                    let isHead = i == currentTickIndex && fraction > 0
                    
                    Capsule()
                        .fill(isActive ? color : Color.white.opacity(isStep ? 0.3 : 0.1))
                        .frame(width: isHead ? 3.5 : (isStep ? 2.5 : 1.2), 
                               height: isHead ? size * 0.07 : (isStep ? size * 0.05 : size * 0.03))
                        .offset(y: -(radius * 0.9))
                        .rotationEffect(.degrees(Double(i) * 6))
                        .shadow(color: isHead ? color : (isActive ? color.opacity(0.5) : .clear), 
                                radius: isHead ? 8 : 4)
                        .scaleEffect(isHead ? 1.15 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: fraction)
                }
                
                // 3. Active Progress Ring (Outer)
                Circle()
                    .trim(from: 0.0, to: fraction)
                    .stroke(
                        AngularGradient(
                            colors: [color.opacity(0.3), color, color],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360 * fraction)
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: size * 0.82, height: size * 0.82)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: color.opacity(0.3), radius: 5)
                    .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.8), value: fraction)

                // Track Background for full rounds
                if rounds > 0 && !isFullRound {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: sectorRadius * 2, height: sectorRadius * 2)
                }

                // Active Sector
                if isFullRound || (rounds > 0 && isRunning && fraction == 1) {
                    Circle()
                        .fill(
                            LinearGradient(colors: [color.opacity(0.2), color.opacity(0.5)], startPoint: .top, endPoint: .bottom)
                        )
                        .frame(width: sectorRadius * 2, height: sectorRadius * 2)
                } else if fraction > 0 {
                    SectorShape(angle: .degrees(fraction * 360))
                        .fill(
                            LinearGradient(colors: [color.opacity(0.2), color.opacity(0.5)], startPoint: .top, endPoint: .bottom)
                        )
                        .frame(width: sectorRadius * 2, height: sectorRadius * 2)
                        .rotationEffect(.degrees(-90))
                }
                
                // Active outline / inner rim
                Circle()
                    .stroke(color.opacity(0.3), lineWidth: 1)
                    .frame(width: sectorRadius * 2, height: sectorRadius * 2)

                // Dragging Hand (Only when not running)
                if !isRunning {
                    let handAngle = Angle.degrees(fraction * 360)
                    
                    ZStack {
                        // The line spanning from center outwards
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 3, height: sectorRadius)
                            .offset(y: -sectorRadius / 2)
                            .shadow(color: .white.opacity(0.8), radius: 4)

                        // Center dot
                        Circle()
                            .fill(Color.white)
                            .frame(width: 14, height: 14)
                            .shadow(color: .white.opacity(0.8), radius: 4)
                        
                        // Hand tip (Invisible, for drag area enhancement if needed, but we drag anywhere)
                    }
                    .rotationEffect(handAngle)
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

struct SectorShape: Shape {
    var angle: Angle
    
    var animatableData: Double {
        get { angle.degrees }
        set { angle = Angle(degrees: newValue) }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        
        path.move(to: center)
        // 0 degrees is right side. We rotate -90 at view level, so start at 0
        path.addArc(center: center,
                    radius: radius,
                    startAngle: .degrees(0),
                    endAngle: angle,
                    clockwise: false)
        path.closeSubpath()
        return path
    }
}
