import SwiftUI

struct ProgressHeader: View {
    let step: Int
    let total: Int
    
    private var inactiveSegmentWidth: CGFloat {
        if total >= 12 { return 10 }
        if total >= 9 { return 12 }
        return 20
    }
    
    private var currentSegmentWidth: CGFloat {
        inactiveSegmentWidth * 1.6
    }
    
    private var segmentSpacing: CGFloat {
        total >= 12 ? 4 : 8
    }

    private var isTiimo: Bool {
        SettingsStore.shared.alarmThemeStyle == .tiimo
    }

    var body: some View {
        if isTiimo {
            // Tiimo Light continuous progress bar style
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(hex: "#E8E4F5"))
                        .frame(height: 4)
                    
                    Capsule()
                        .fill(Color(hex: "#7F77DD"))
                        .frame(width: geometry.size.width * CGFloat(step) / CGFloat(total), height: 4)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: step)
                }
            }
            .frame(height: 4)
            .padding(.vertical, 16)
        } else {
            HStack(spacing: 12) {
                // Premium Segmented Progress
                HStack(spacing: segmentSpacing) {
                    ForEach(1...total, id: \.self) { index in
                        let isCompletedOrCurrent = index <= step
                        let isCurrent = index == step
                        
                        Capsule()
                            .fill(
                                isCompletedOrCurrent ? 
                                    AnyShapeStyle(LinearGradient(colors: [Colors.accentTeal, Colors.accentBlue], startPoint: .leading, endPoint: .trailing)) :
                                    AnyShapeStyle(Color.white.opacity(0.15))
                            )
                            .frame(height: isCurrent ? 6 : 4)
                            .frame(width: isCurrent ? currentSegmentWidth : inactiveSegmentWidth)
                            .opacity(isCompletedOrCurrent ? 1.0 : 0.5)
                            .shadow(color: isCurrent ? Colors.accentTeal.opacity(0.6) : .clear, radius: 6, x: 0, y: 0)
                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: step)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Stylish Progress Badge
                Text("\(step) of \(total)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(Colors.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            }
            .padding(.vertical, 8)
        }
    }
}
