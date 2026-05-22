import SwiftUI

struct HabitGoalCelebrationOverlay: View {
    var habitTitle: String?

    @State private var reveal = false

    var body: some View {
        ZStack {
            Color.black.opacity(reveal ? 0.22 : 0)
                .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Colors.accentBlue.opacity(reveal ? 0.22 : 0),
                    Colors.accentTeal.opacity(reveal ? 0.18 : 0),
                    Color(red: 0.56, green: 0.45, blue: 0.95).opacity(reveal ? 0.10 : 0),
                    .clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 340
            )
            .ignoresSafeArea()

            SoftCelebrationBackground()
                .opacity(reveal ? 1 : 0)
                .scaleEffect(reveal ? 1 : 0.97)

            FallingEmojiBurstView()
                .opacity(reveal ? 1 : 0)
                .zIndex(2)

            RisingConfettiStreaks()
                .opacity(reveal ? 1 : 0)
                .zIndex(1)
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeOut(duration: 0.35)) {
                reveal = true
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }
}

private struct SoftCelebrationBackground: View {
    private let particles: [SoftCelebrationParticle] = (0..<30).map { _ in .random() }
    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { particle in
                    SoftCelebrationParticleView(
                        particle: particle,
                        size: geo.size,
                        phase: localPhase(for: particle)
                    )
                }
            }
            .onAppear {
                withAnimation(.easeOut(duration: 1.9)) {
                    phase = 1
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func localPhase(for particle: SoftCelebrationParticle) -> CGFloat {
        let delay = CGFloat(particle.delay)
        let denominator = max(1 - delay, 0.001)
        let raw = (phase - delay) / denominator
        return min(max(raw, 0), 1)
    }
}

private struct SoftCelebrationParticleView: View {
    let particle: SoftCelebrationParticle
    let size: CGSize
    let phase: CGFloat

    var body: some View {
        Circle()
            .fill(particle.color.opacity(0.95))
            .frame(width: particle.size, height: particle.size)
            .blur(radius: particle.blur)
            .scaleEffect(0.55 + (phase * 0.5))
            .position(x: xPosition, y: yPosition)
            .opacity(opacity)
    }

    private var xPosition: CGFloat {
        size.width * (particle.startX + (particle.driftX * phase))
    }

    private var yPosition: CGFloat {
        let startY = size.height + particle.bottomOffset
        let endY = size.height * particle.endY
        return startY + ((endY - startY) * phase)
    }

    private var opacity: Double {
        let value: CGFloat
        if phase < 0.18 {
            value = phase / 0.18
        } else {
            value = 1 - phase
        }
        return Double(max(min(value, 1), 0)) * 0.85
    }
}

private struct SoftCelebrationParticle: Identifiable {
    let id = UUID()
    let color: Color
    let startX: CGFloat
    let driftX: CGFloat
    let endY: CGFloat
    let size: CGFloat
    let bottomOffset: CGFloat
    let delay: Double
    let blur: CGFloat

    static func random() -> SoftCelebrationParticle {
        let palette: [Color] = [
            Colors.accentTeal,
            Colors.accentBlue,
            Color(red: 0.30, green: 0.82, blue: 0.98),
            Color(red: 0.58, green: 0.45, blue: 0.95),
            Color.white.opacity(0.95)
        ]

        return SoftCelebrationParticle(
            color: palette.randomElement() ?? .white,
            startX: CGFloat.random(in: 0.03...0.97),
            driftX: CGFloat.random(in: -0.08...0.08),
            endY: CGFloat.random(in: 0.16...0.42),
            size: CGFloat.random(in: 6...16),
            bottomOffset: CGFloat.random(in: 12...90),
            delay: Double.random(in: 0...0.58),
            blur: CGFloat.random(in: 0.2...1.2)
        )
    }
}

private struct FallingEmojiBurstView: View {
    @State private var animate = false
    private let pieces: [FallingEmojiPiece] = (0..<72).map { _ in .random() }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { piece in
                    Group {
                        switch piece.kind {
                        case .emoji(let symbol):
                            Text(symbol)
                                .font(.system(size: piece.size * 1.4))
                        case .chip(let color):
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(color)
                                .frame(width: piece.size * 0.75, height: piece.size * 0.42)
                        }
                    }
                    .rotationEffect(.degrees(animate ? piece.endRotation : piece.startRotation))
                    .position(x: piece.startX * geo.size.width, y: -24)
                    .offset(
                        x: animate ? piece.driftX : 0,
                        y: animate ? geo.size.height + piece.travelY : 0
                    )
                    .opacity(animate ? 0.95 : 0)
                    .animation(.easeIn(duration: piece.duration).delay(piece.delay), value: animate)
                }
            }
            .onAppear {
                animate = true
            }
        }
        .allowsHitTesting(false)
    }
}

private struct RisingConfettiStreaks: View {
    private let streaks: [ConfettiStreak] = (0..<28).map { _ in .random() }
    @State private var animate = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(streaks) { streak in
                    RoundedRectangle(cornerRadius: streak.width / 2, style: .continuous)
                        .fill(streak.color.opacity(0.85))
                        .frame(width: streak.width, height: streak.height)
                        .rotationEffect(.degrees(streak.rotation))
                        .position(
                            x: geo.size.width * streak.startX,
                            y: animate ? geo.size.height * streak.endY : geo.size.height + streak.offsetY
                        )
                        .opacity(animate ? 0 : 0.95)
                        .animation(.easeOut(duration: streak.duration).delay(streak.delay), value: animate)
                }
            }
            .onAppear {
                animate = true
            }
        }
        .allowsHitTesting(false)
    }
}

private struct ConfettiStreak: Identifiable {
    let id = UUID()
    let color: Color
    let startX: CGFloat
    let endY: CGFloat
    let offsetY: CGFloat
    let width: CGFloat
    let height: CGFloat
    let rotation: Double
    let delay: Double
    let duration: Double

    static func random() -> ConfettiStreak {
        let colors: [Color] = [
            Colors.accentBlue,
            Colors.accentTeal,
            Color(red: 0.56, green: 0.45, blue: 0.95),
            Color(red: 0.31, green: 0.84, blue: 0.98),
            Color.white
        ]
        return ConfettiStreak(
            color: colors.randomElement() ?? .white,
            startX: CGFloat.random(in: 0.02...0.98),
            endY: CGFloat.random(in: 0.14...0.42),
            offsetY: CGFloat.random(in: 8...66),
            width: CGFloat.random(in: 4...8),
            height: CGFloat.random(in: 14...28),
            rotation: Double.random(in: -45...45),
            delay: Double.random(in: 0...0.35),
            duration: Double.random(in: 0.7...1.3)
        )
    }
}

private struct FallingEmojiPiece: Identifiable {
    enum Kind {
        case emoji(String)
        case chip(Color)
    }

    let id = UUID()
    let kind: Kind
    let startX: CGFloat
    let driftX: CGFloat
    let travelY: CGFloat
    let size: CGFloat
    let delay: Double
    let duration: Double
    let startRotation: Double
    let endRotation: Double

    static func random() -> FallingEmojiPiece {
        let emojis = ["🎉", "🎊", "✨", "🥳", "💫"]
        let palette: [Color] = [
            Colors.accentTeal,
            Colors.accentBlue,
            Color(red: 0.30, green: 0.82, blue: 0.98),
            Color(red: 0.58, green: 0.45, blue: 0.95)
        ]
        let isEmoji = Double.random(in: 0...1) < 0.55

        return FallingEmojiPiece(
            kind: isEmoji ? .emoji(emojis.randomElement() ?? "🎉") : .chip(palette.randomElement() ?? .white),
            startX: CGFloat.random(in: -0.05...1.05),
            driftX: CGFloat.random(in: -90...90),
            travelY: CGFloat.random(in: 40...180),
            size: CGFloat.random(in: 12...24),
            delay: Double.random(in: 0...0.65),
            duration: Double.random(in: 1.55...2.25),
            startRotation: Double.random(in: -30...30),
            endRotation: Double.random(in: 180...760)
        )
    }
}
