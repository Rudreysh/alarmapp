import SwiftUI

struct AlarmGreetingView: View {
    let onDismiss: () -> Void

    @State private var textAppeared = false
    @State private var subtextAppeared = false
    @State private var dismissed = false

    private let content = AlarmGreetingContent.forCurrentTime()

    var body: some View {
        ZStack {
            backgroundLayer
            softGlowLayer
            GeometryReader { geo in
                emojiLayer(size: geo.size)
            }
            .allowsHitTesting(false)
            centerTextLayer
        }
        .onAppear {
            withAnimation(.spring(response: 0.65, dampingFraction: 0.72)) {
                textAppeared = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.18)) {
                subtextAppeared = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                triggerDismiss()
            }
        }
    }

    private var backgroundLayer: some View {
        LinearGradient(
            colors: content.backgroundColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var softGlowLayer: some View {
        GeometryReader { geo in
            Circle()
                .fill(Color.white.opacity(0.09))
                .frame(width: geo.size.width * 1.3)
                .position(x: geo.size.width * 0.1, y: geo.size.height * 0.15)
                .blur(radius: 70)
            Circle()
                .fill(Color.white.opacity(0.07))
                .frame(width: geo.size.width * 1.0)
                .position(x: geo.size.width * 0.9, y: geo.size.height * 0.82)
                .blur(radius: 55)
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    private func emojiLayer(size: CGSize) -> some View {
        let w = size.width
        let h = size.height
        let configs = AlarmGreetingView.emojiConfigs(for: content.emojis, screenWidth: w, screenHeight: h)

        return ForEach(configs.indices, id: \.self) { i in
            FloatingEmojiView(
                emoji: configs[i].emoji,
                size: configs[i].size,
                x: configs[i].x,
                y: configs[i].y,
                floatAmplitude: configs[i].amplitude,
                floatDuration: configs[i].duration,
                rotationRange: configs[i].rotation,
                entranceDelay: Double(i) * 0.1
            )
        }
    }

    private var centerTextLayer: some View {
        VStack(spacing: 14) {
            Text(content.greeting)
                .font(.system(size: 46, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.22), radius: 16, x: 0, y: 4)
                .scaleEffect(textAppeared ? 1.0 : 0.68)
                .opacity(textAppeared ? 1.0 : 0.0)

            Text(content.subtext)
                .font(.system(size: 21, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.88))
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
                .opacity(subtextAppeared ? 1.0 : 0.0)
                .offset(y: subtextAppeared ? 0 : 12)
        }
        .padding(.horizontal, 36)
    }

    private func triggerDismiss() {
        guard !dismissed else { return }
        dismissed = true
        onDismiss()
    }

    private static func emojiConfigs(
        for emojis: [String],
        screenWidth w: CGFloat,
        screenHeight h: CGFloat
    ) -> [EmojiConfig] {
        let positions: [(CGFloat, CGFloat)] = [
            (0.10, 0.10),
            (0.82, 0.09),
            (0.18, 0.27),
            (0.76, 0.24),
            (0.05, 0.65),
            (0.88, 0.62),
            (0.18, 0.85),
            (0.74, 0.86),
        ]
        let sizes: [CGFloat]    = [48, 42, 36, 52, 44, 38, 46, 40]
        let amplitudes: [CGFloat] = [10, 13, 8, 12, 11, 14, 9, 11]
        let durations: [Double]  = [2.8, 3.2, 2.6, 3.5, 2.9, 3.0, 2.7, 3.3]
        let rotations: [Double]  = [10, 12, 8, 14, 10, 12, 9, 11]

        return emojis.prefix(8).enumerated().map { i, emoji in
            let pos = positions[i % positions.count]
            return EmojiConfig(
                emoji: emoji,
                x: w * pos.0,
                y: h * pos.1,
                size: sizes[i % sizes.count],
                amplitude: amplitudes[i % amplitudes.count],
                duration: durations[i % durations.count],
                rotation: rotations[i % rotations.count]
            )
        }
    }

    struct EmojiConfig {
        let emoji: String
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let amplitude: CGFloat
        let duration: Double
        let rotation: Double
    }
}

private struct FloatingEmojiView: View {
    let emoji: String
    let size: CGFloat
    let x: CGFloat
    let y: CGFloat
    let floatAmplitude: CGFloat
    let floatDuration: Double
    let rotationRange: Double
    let entranceDelay: Double

    @State private var floatUp = false
    @State private var rotateCW = false
    @State private var appeared = false

    var body: some View {
        Text(emoji)
            .font(.system(size: size))
            .scaleEffect(appeared ? 1.0 : 0.1)
            .opacity(appeared ? 1.0 : 0.0)
            .rotationEffect(.degrees(rotateCW ? rotationRange : -rotationRange))
            .offset(y: floatUp ? -floatAmplitude : floatAmplitude)
            .position(x: x, y: y)
            .onAppear {
                withAnimation(
                    .spring(response: 0.55, dampingFraction: 0.62)
                    .delay(entranceDelay)
                ) {
                    appeared = true
                }
                withAnimation(
                    .easeInOut(duration: floatDuration)
                    .repeatForever(autoreverses: true)
                    .delay(entranceDelay)
                ) {
                    floatUp = true
                }
                withAnimation(
                    .easeInOut(duration: floatDuration * 1.5)
                    .repeatForever(autoreverses: true)
                    .delay(entranceDelay * 0.6)
                ) {
                    rotateCW = true
                }
            }
    }
}

struct AlarmGreetingContent {
    let greeting: String
    let subtext: String
    let emojis: [String]
    let backgroundColors: [Color]

    static func forCurrentTime() -> AlarmGreetingContent {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return AlarmGreetingContent(
                greeting: "Good Morning!",
                subtext: "Rise and shine ✨",
                emojis: ["☀️", "🌅", "🌸", "🌿", "☕", "🐦", "🌻", "✨"],
                backgroundColors: [
                    Color(red: 1.00, green: 0.60, blue: 0.10),
                    Color(red: 1.00, green: 0.82, blue: 0.28),
                    Color(red: 0.98, green: 0.46, blue: 0.16),
                ]
            )
        case 12..<17:
            return AlarmGreetingContent(
                greeting: "Good Afternoon!",
                subtext: "Have a wonderful day",
                emojis: ["🌤️", "🌊", "🌺", "🦋", "🌻", "✨", "🌈", "🍃"],
                backgroundColors: [
                    Color(red: 0.12, green: 0.52, blue: 0.95),
                    Color(red: 0.22, green: 0.74, blue: 0.98),
                    Color(red: 0.08, green: 0.60, blue: 0.84),
                ]
            )
        case 17..<21:
            return AlarmGreetingContent(
                greeting: "Good Evening!",
                subtext: "Time to wind down",
                emojis: ["🌆", "🌠", "🌙", "⭐", "🦉", "🕯️", "🌸", "🌅"],
                backgroundColors: [
                    Color(red: 0.86, green: 0.32, blue: 0.12),
                    Color(red: 0.62, green: 0.18, blue: 0.52),
                    Color(red: 0.40, green: 0.12, blue: 0.68),
                ]
            )
        default:
            return AlarmGreetingContent(
                greeting: "Good Night!",
                subtext: "Rest well, you've earned it",
                emojis: ["🌙", "⭐", "💫", "🌌", "🦉", "✨", "🌟", "💤"],
                backgroundColors: [
                    Color(red: 0.06, green: 0.06, blue: 0.28),
                    Color(red: 0.12, green: 0.10, blue: 0.42),
                    Color(red: 0.16, green: 0.06, blue: 0.36),
                ]
            )
        }
    }
}
