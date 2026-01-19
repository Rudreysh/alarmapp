import SwiftUI

struct DifficultySliderView: View {
    @Binding var difficulty: MathDifficulty
    let levels = MathDifficulty.allCases
    
    var body: some View {
        VStack(spacing: 20) {
            Text(difficulty.displayName)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 4)
                    
                    // Active Track
                    Rectangle()
                        .fill(Color.cyan)
                        .frame(width: CGFloat(difficulty.rawValue) / CGFloat(levels.count - 1) * geometry.size.width, height: 4)
                    
                    // Dots
                    HStack(spacing: 0) {
                        ForEach(levels, id: \.self) { level in
                            Circle()
                                .fill(level.rawValue <= difficulty.rawValue ? Color.cyan : Color.white.opacity(0.3))
                                .frame(width: 8, height: 8)
                                .frame(maxWidth: .infinity)
                                .onTapGesture {
                                    withAnimation(.spring()) {
                                        difficulty = level
                                    }
                                }
                        }
                    }
                    
                    // Knob
                    Circle()
                        .fill(Color.white)
                        .frame(width: 24, height: 24)
                        .offset(x: (CGFloat(difficulty.rawValue) / CGFloat(levels.count - 1) * geometry.size.width) - 12)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let percent = max(0, min(1, value.location.x / geometry.size.width))
                                    let index = Int(round(percent * CGFloat(levels.count - 1)))
                                    if let newDifficulty = MathDifficulty(rawValue: index) {
                                        if difficulty != newDifficulty {
                                            difficulty = newDifficulty
                                        }
                                    }
                                }
                        )
                }
            }
            .frame(height: 30)
            
            HStack {
                Text("Very easy")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Colors.textSecondary)
                Spacer()
                Text("Hell mode")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Colors.textSecondary)
            }
        }
        .padding(24)
        .background(Colors.cardSurface)
        .cornerRadius(24)
    }
}

struct NumericKeypadView: View {
    let onDigit: (String) -> Void
    let onDelete: () -> Void
    let onSubmit: () -> Void
    let isDisabled: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // Row 1: 1 2 3 Backspace
            HStack(spacing: 12) {
                keyButton("1")
                keyButton("2")
                keyButton("3")
                actionButton(icon: "delete.left.fill", color: Color.white.opacity(0.2), action: onDelete)
            }
            
            // Row 2: 4 5 6 Checkmark
            HStack(spacing: 12) {
                keyButton("4")
                keyButton("5")
                keyButton("6")
                actionButton(icon: "checkmark", color: Color.red.opacity(0.8), action: onSubmit)
            }
            
            // Row 3: 7 8 9 0
            HStack(spacing: 12) {
                keyButton("7")
                keyButton("8")
                keyButton("9")
                keyButton("0")
            }
        }
        .disabled(isDisabled)
    }
    
    private func keyButton(_ digit: String) -> some View {
        Button(action: { onDigit(digit) }) {
            Text(digit)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
        }
    }
    
    private func actionButton(icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .background(color)
                .cornerRadius(12)
        }
    }
}
