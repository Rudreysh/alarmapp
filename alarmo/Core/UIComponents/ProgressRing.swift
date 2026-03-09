import SwiftUI

struct ProgressRing: View {
    let progress: Double
    let color: Color
    var showTicks: Bool = false
    
    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let radius = size / 2
            
            ZStack {
                // 1. Ambient Background Glow
                Circle()
                    .stroke(color.opacity(0.06), lineWidth: 8)
                    .blur(radius: 6)
                    .frame(width: size * 1.05, height: size * 1.05)
                
                Circle()
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    .frame(width: size, height: size)

                // 2. Sun Ray Ticks
                ForEach(0..<60) { i in
                    let isStep = i % 5 == 0
                    let tickFraction = Double(i) / 60.0
                    let isPassed = tickFraction <= (progress + 0.005)
                    
                    let headIndex = Int(round(progress * 60)) % 60
                    let isHead = i == headIndex && progress > 0
                    
                    Capsule()
                        .fill(isPassed ? color : Color.white.opacity(isStep ? 0.3 : 0.1))
                        .frame(width: isHead ? 3.5 : (isStep ? 2.5 : 1.2), 
                               height: isHead ? size * 0.08 : (isStep ? size * 0.06 : size * 0.03))
                        .offset(y: -(radius * 0.95))
                        .rotationEffect(.degrees(Double(i) * 6))
                        .shadow(color: isHead ? color : (isPassed ? color.opacity(0.5) : .clear), 
                                radius: isHead ? 8 : 4)
                        .scaleEffect(isHead ? 1.15 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: progress)
                }
                
                // 3. Thin Gradient Stroke
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            colors: [color.opacity(0.2), color],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360 * progress)
                        ),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: size * 0.88, height: size * 0.88)
                    .shadow(color: color.opacity(0.3), radius: 5)
                    .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.8), value: progress)
            }
            .frame(width: size, height: size)
            .position(x: geo.size.width / 2, y: geo.size.height / 2) // Center in the geometry
        }
    }
}
