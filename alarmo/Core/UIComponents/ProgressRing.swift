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
                // Background Ticks (All 60)
                ForEach(0..<60) { i in
                    let isStep = i % 5 == 0
                    Rectangle()
                        .fill(Color.white.opacity(0.22))
                        .frame(width: isStep ? 1.5 : 1, height: isStep ? size * 0.05 : size * 0.02)
                        .offset(y: -(radius * 0.95))
                        .rotationEffect(.degrees(Double(i) * 6))
                }
                
                // Active Progress Ticks (Up to current progress)
                ForEach(0..<60) { i in
                    let isStep = i % 5 == 0
                    let isPassed = i <= Int(progress * 60)
                    
                    if isPassed {
                        Rectangle()
                            .fill(color)
                            .frame(width: isStep ? 3 : 1.5, height: isStep ? size * 0.06 : size * 0.03)
                            .offset(y: -(radius * 0.95))
                            .rotationEffect(.degrees(Double(i) * 6))
                            .shadow(color: color.opacity(0.8), radius: 6)
                    }
                }
                
                // The "Leading" Tick (Highlighted)
                let leadIndex = Int(progress * 60) % 60
                Rectangle()
                    .fill(color)
                    .frame(width: 3, height: size * 0.08)
                    .offset(y: -(radius * 0.95))
                    .rotationEffect(.degrees(Double(leadIndex) * 6))
                    .shadow(color: color, radius: 10)
                
                // Main Progress Stroke (Very thin line behind ticks)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color.opacity(0.1), style: StrokeStyle(lineWidth: 1, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(radius * 0.05)
            }
            .frame(width: size, height: size)
            .position(x: geo.size.width / 2, y: geo.size.height / 2) // Center in the geometry
        }
    }
}
