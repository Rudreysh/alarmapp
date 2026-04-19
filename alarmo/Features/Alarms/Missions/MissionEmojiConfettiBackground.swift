import SwiftUI

struct MissionEmojiConfettiBackground: View {
    private static let particles: [MissionEmojiConfettiParticle] = MissionEmojiConfettiParticle.makeBursts()
    @State private var animateOut = false
    @State private var spinOut = false

    var body: some View {
        GeometryReader { proxy in
            let center = CGPoint(
                x: proxy.size.width * 0.5,
                y: proxy.size.height * 0.35
            )

            ZStack {
                ForEach(Self.particles) { particle in
                    Text(particle.emoji)
                        .font(.system(size: particle.size))
                        .position(
                            x: center.x + (animateOut ? cos(particle.angle) * particle.distance : 0),
                            y: center.y + (animateOut ? sin(particle.angle) * particle.distance + particle.fall : 0)
                        )
                        .scaleEffect(animateOut ? particle.finalScale : 0.85)
                        .rotationEffect(.degrees(spinOut ? particle.rotation : 0))
                        .opacity(animateOut ? 0 : 1)
                        .animation(
                            .timingCurve(0.2, 0.8, 0.2, 1.0, duration: particle.duration)
                                .delay(particle.delay),
                            value: animateOut
                        )
                        .animation(
                            .linear(duration: particle.duration).delay(particle.delay),
                            value: spinOut
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .allowsHitTesting(false)
        .onAppear {
            animateOut = false
            spinOut = false
            DispatchQueue.main.async {
                spinOut = true
                animateOut = true
            }
        }
    }
}

private struct MissionEmojiConfettiParticle: Identifiable {
    let id: Int
    let emoji: String
    let angle: CGFloat
    let distance: CGFloat
    let fall: CGFloat
    let delay: Double
    let duration: Double
    let size: CGFloat
    let finalScale: CGFloat
    let rotation: Double

    static func makeBursts(totalPerBurst: Int = 16) -> [MissionEmojiConfettiParticle] {
        let emojis = ["🦄", "🎉", "✨", "🎊", "⭐️", "💫"]
        var particles: [MissionEmojiConfettiParticle] = []
        var currentId = 0

        for burst in 0..<3 {
            for _ in 0..<totalPerBurst {
                particles.append(
                    MissionEmojiConfettiParticle(
                        id: currentId,
                        emoji: emojis.randomElement() ?? "✨",
                        angle: CGFloat.random(in: 0...(2 * .pi)),
                        distance: CGFloat.random(in: 80...220),
                        fall: CGFloat.random(in: 36...140),
                        delay: Double(burst) * 0.10 + Double.random(in: 0...0.05),
                        duration: Double.random(in: 0.85...1.25),
                        size: CGFloat.random(in: 18...30),
                        finalScale: CGFloat.random(in: 0.45...0.9),
                        rotation: Double.random(in: -210...210)
                    )
                )
                currentId += 1
            }
        }

        return particles
    }
}
