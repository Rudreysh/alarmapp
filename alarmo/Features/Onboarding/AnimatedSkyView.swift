import SwiftUI

struct AnimatedSkyView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sunRaised = false
    @State private var glowExpanded = false
    @State private var cloudOneDrifted = false
    @State private var cloudTwoDrifted = false
    @State private var cloudThreeDrifted = false
    @State private var birdFlightProgress: CGFloat = 0
    @State private var sway = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 251 / 255, green: 243 / 255, blue: 232 / 255),
                        Color(red: 255 / 255, green: 249 / 255, blue: 241 / 255)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                sun(in: proxy)

                DriftingCloud(
                    scale: 1.0,
                    opacity: 0.92,
                    yPosition: proxy.size.height * 0.15,
                    startX: -90,
                    endX: proxy.size.width + 90,
                    didDrift: cloudOneDrifted,
                    reduceMotion: reduceMotion,
                    sway: sway,
                    swayOffset: 5.5
                )
                .animation(.linear(duration: 22).repeatForever(autoreverses: false), value: cloudOneDrifted)
                .animation(.easeInOut(duration: 4.8).repeatForever(autoreverses: true), value: sway)

                DriftingCloud(
                    scale: 0.78,
                    opacity: 0.78,
                    yPosition: proxy.size.height * 0.25,
                    startX: proxy.size.width + 80,
                    endX: -80,
                    didDrift: cloudTwoDrifted,
                    reduceMotion: reduceMotion,
                    sway: sway,
                    swayOffset: -4.0
                )
                .animation(.linear(duration: 30).repeatForever(autoreverses: false), value: cloudTwoDrifted)
                .animation(.easeInOut(duration: 5.6).repeatForever(autoreverses: true), value: sway)

                DriftingCloud(
                    scale: 0.62,
                    opacity: 0.6,
                    yPosition: proxy.size.height * 0.10,
                    startX: -70,
                    endX: proxy.size.width + 70,
                    didDrift: cloudThreeDrifted,
                    reduceMotion: reduceMotion,
                    sway: sway,
                    swayOffset: 3.5
                )
                .animation(.linear(duration: 26).repeatForever(autoreverses: false), value: cloudThreeDrifted)
                .animation(.easeInOut(duration: 4.2).repeatForever(autoreverses: true), value: sway)

                BirdsFlyby(progress: reduceMotion ? 0.22 : birdFlightProgress)
                    .frame(width: 38, height: 18)
                    .position(
                        x: -40 + (proxy.size.width + 80) * (reduceMotion ? 0.22 : birdFlightProgress),
                        y: proxy.size.height * 0.19 - 44 * (reduceMotion ? 0.22 : birdFlightProgress)
                    )
                    .modifier(BirdFadeModifier(progress: reduceMotion ? 0.22 : birdFlightProgress))
                    .animation(.linear(duration: 18).repeatForever(autoreverses: false), value: birdFlightProgress)
            }
            .clipped()
            .onAppear {
                guard !reduceMotion else { return }
                sunRaised = true
                glowExpanded = true
                cloudOneDrifted = true
                cloudTwoDrifted = true
                cloudThreeDrifted = true
                birdFlightProgress = 1
                
                withAnimation(.easeInOut(duration: 4.5).repeatForever(autoreverses: true)) {
                    sway = true
                }
            }
            .onChange(of: reduceMotion) { _, isReduced in
                guard isReduced else { return }
                sunRaised = false
                glowExpanded = false
                cloudOneDrifted = false
                cloudTwoDrifted = false
                cloudThreeDrifted = false
                birdFlightProgress = 0
                sway = false
            }
        }
        .ignoresSafeArea()
    }

    private func sun(in proxy: GeometryProxy) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 255 / 255, green: 213 / 255, blue: 107 / 255).opacity(0.42),
                            Color(red: 252 / 255, green: 177 / 255, blue: 58 / 255).opacity(0)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 66
                    )
                )
                .frame(width: 108, height: 108)
                .scaleEffect(reduceMotion ? 1.06 : (glowExpanded ? 1.15 : 1.0))
                .opacity(reduceMotion ? 0.86 : (glowExpanded ? 1.0 : 0.76))
                .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: glowExpanded)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 255 / 255, green: 213 / 255, blue: 107 / 255),
                            Color(red: 252 / 255, green: 177 / 255, blue: 58 / 255)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 35
                    )
                )
                .frame(width: 70, height: 70)
        }
        .position(x: proxy.size.width * 0.5, y: proxy.size.height * 0.16)
        .offset(y: reduceMotion ? 6 : (sunRaised ? -6 : 18))
        .animation(.easeInOut(duration: 6).repeatForever(autoreverses: true), value: sunRaised)
    }
}

private struct DriftingCloud: View {
    let scale: CGFloat
    let opacity: Double
    let yPosition: CGFloat
    let startX: CGFloat
    let endX: CGFloat
    let didDrift: Bool
    let reduceMotion: Bool
    let sway: Bool
    let swayOffset: CGFloat

    var body: some View {
        CloudShapeView()
            .frame(width: 76 * scale, height: 34 * scale)
            .opacity(opacity)
            .position(x: reduceMotion ? (startX + endX) * 0.5 : (didDrift ? endX : startX), y: yPosition)
            .offset(y: reduceMotion ? 0 : (sway ? swayOffset : -swayOffset))
    }
}

private struct CloudShapeView: View {
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Capsule(style: .continuous)
                .fill(Color.white)
                .frame(width: 76, height: 22)
                .offset(y: 10)

            Circle()
                .fill(Color.white)
                .frame(width: 34, height: 34)
                .offset(x: 12, y: -1)

            Circle()
                .fill(Color.white)
                .frame(width: 26, height: 26)
                .offset(x: 38, y: 4)
        }
        .frame(width: 76, height: 44, alignment: .bottomLeading)
        .shadow(color: Color(red: 190 / 255, green: 160 / 255, blue: 120 / 255).opacity(0.08), radius: 12, x: 0, y: 6)
    }
}

private struct BirdsFlyby: View {
    let progress: CGFloat

    var body: some View {
        BirdsPath()
            .trim(from: 0, to: 1)
            .stroke(
                Color(red: 176 / 255, green: 147 / 255, blue: 106 / 255),
                style: StrokeStyle(lineWidth: 1.35, lineCap: .round, lineJoin: .round)
            )
    }
}

private struct BirdsPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        path.move(to: CGPoint(x: w * 0.05, y: h * 0.58))
        path.addQuadCurve(to: CGPoint(x: w * 0.27, y: h * 0.58), control: CGPoint(x: w * 0.16, y: h * 0.18))
        path.addQuadCurve(to: CGPoint(x: w * 0.49, y: h * 0.58), control: CGPoint(x: w * 0.38, y: h * 0.18))

        path.move(to: CGPoint(x: w * 0.55, y: h * 0.46))
        path.addQuadCurve(to: CGPoint(x: w * 0.75, y: h * 0.46), control: CGPoint(x: w * 0.65, y: h * 0.12))
        path.addQuadCurve(to: CGPoint(x: w * 0.95, y: h * 0.46), control: CGPoint(x: w * 0.85, y: h * 0.12))

        return path
    }
}

private struct BirdFadeModifier: AnimatableModifier {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content.opacity(opacity(for: progress))
    }

    private func opacity(for progress: CGFloat) -> Double {
        switch progress {
        case ..<0.08:
            return Double(progress / 0.08) * 0.55
        case 0.08..<0.86:
            return 0.55
        case 0.86...1:
            return Double(max(0, (1 - progress) / 0.14)) * 0.55
        default:
            return 0
        }
    }
}
