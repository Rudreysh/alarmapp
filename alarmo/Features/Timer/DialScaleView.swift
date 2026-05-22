import SwiftUI

struct DialScaleView: View {
    let theme: PomodoroTheme
    let centerValue: Int
    
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let tickSpacing: CGFloat = width / 10
            
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(-5...5, id: \.self) { i in
                    VStack(spacing: 8) {
                        // Numeric label for major ticks
                        if i % 5 == 0 {
                            Text("\(centerValue + i)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(theme.primaryText)
                        } else {
                            Text("")
                                .font(.system(size: 14))
                                .frame(height: 16)
                        }
                        
                        // Vertical tick
                        Rectangle()
                            .fill(i == 0 ? theme.primaryText : theme.dialTick)
                            .frame(width: 1.5, height: i % 5 == 0 ? 30 : 15)
                    }
                    .frame(width: tickSpacing)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 100)
    }
}
