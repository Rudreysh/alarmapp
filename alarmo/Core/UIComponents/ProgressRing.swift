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
                // Background Circle
                Circle()
                    .stroke(Colors.cardStroke, lineWidth: 4)
                
                if showTicks {
                    // Decorative Ticks for Stopwatch
                    ForEach(0..<60) { i in
                        Rectangle()
                            .fill(i < Int(progress * 60) ? color : Colors.textTertiary)
                            .frame(width: 2, height: i % 5 == 0 ? size * 0.033 : size * 0.016)
                            .offset(y: -(radius * 0.9)) // Dynamic offset
                            .rotationEffect(.degrees(Double(i) * 6))
                    }
                } else {
                    // Progress Stroke for Pomo
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear, value: progress)
                }
            }
            .frame(width: size, height: size)
            .position(x: geo.size.width / 2, y: geo.size.height / 2) // Center in the geometry
        }
    }
}
