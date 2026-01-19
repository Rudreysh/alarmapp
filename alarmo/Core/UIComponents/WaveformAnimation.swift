import SwiftUI

struct WaveformAnimation: View {
    @State private var phase: CGFloat = 0
    let color: Color
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(color)
                    .frame(width: 2)
                    .frame(height: height(for: index))
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 0.6).repeatForever(autoreverses: true)) {
                phase = 1.0
            }
        }
    }
    
    private func height(for index: Int) -> CGFloat {
        let base: CGFloat = 8
        let variance: CGFloat = 10
        let offset = CGFloat(index) * 0.2
        let multiplier = sin((phase + offset) * .pi)
        return base + (abs(multiplier) * variance)
    }
}

#Preview {
    ZStack {
        Color.black
        WaveformAnimation(color: .white)
    }
}
