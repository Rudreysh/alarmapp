import SwiftUI
import UIKit
import ImageIO

struct WelcomeView: View {
    var onContinue: () -> Void
    var onSkip: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var skyOpacity = 0.0
    @State private var starRevealCount = 0
    @State private var headlineVisible = false
    @State private var sublineVisible = false
    @State private var mascotVisible = false
    @State private var cloudsDrifting = false
    @State private var metaVisible = false
    @State private var ctaVisible = false
    @State private var mascotBob = false
    @State private var ctaPulse = false
    @State private var typedHeadline = ""
    @State private var typedSubline = ""

    private let headline = "Hey! I'm your alarm."
    private let subline = "I'll help you stop snoozing — and stop scrolling back to sleep."

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                DuskSkyView(
                    starRevealCount: starRevealCount,
                    cloudsDrifting: cloudsDrifting
                )
                .opacity(skyOpacity)

                mascotCluster(in: proxy)
                headlineCard(in: proxy)
                morningCoachCard(in: proxy)
                bottomControls(in: proxy)
                skipButton(in: proxy)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(Color(hex: "0D0820"))
            .ignoresSafeArea()
            .onAppear {
                runEntranceAnimation()
            }
        }
    }

    private func headlineCard(in proxy: GeometryProxy) -> some View {
        Text(typedHeadline.isEmpty ? " " : typedHeadline)
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundColor(Color(hex: "F7EEFF"))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .fixedSize(horizontal: true, vertical: false)
            .frame(maxWidth: proxy.size.width - 60, alignment: .center)
            .background(
                iOSSpeechBubbleShape(cornerRadius: 22, tailWidth: 28, tailHeight: 14, tailOffset: 20)
                    .fill(Color(hex: "1C0E36").opacity(0.68))
                    .background(.ultraThinMaterial)
                    .clipShape(iOSSpeechBubbleShape(cornerRadius: 22, tailWidth: 28, tailHeight: 14, tailOffset: 20))
            )
            .overlay(
                iOSSpeechBubbleShape(cornerRadius: 22, tailWidth: 28, tailHeight: 14, tailOffset: 20)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.24),
                                Color.white.opacity(0.04),
                                Color(hex: "B464DC").opacity(0.18)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            )
            .shadow(color: Color(hex: "080312").opacity(0.35), radius: 16, x: 0, y: 12)
            .opacity(headlineVisible ? 1 : 0)
            .offset(y: headlineVisible ? 0 : -16)
            .position(x: proxy.size.width / 2, y: proxy.size.height * 0.385)
            .accessibilityLabel(headline)
    }

    private func mascotCluster(in proxy: GeometryProxy) -> some View {
        ZStack {
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "120826").opacity(0.34),
                            Color(hex: "271044").opacity(0.18),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 190
                    )
                )
                .frame(width: 380, height: 300)
                .blur(radius: 18)
                .offset(y: 12)

            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "9B59F5").opacity(0.18),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 90
                    )
                )
                .frame(width: 180, height: 90)
                .offset(y: 62)
                .opacity(mascotBob ? 1.0 : 0.6)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 4).repeatForever(autoreverses: true),
                    value: mascotBob
                )

            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.04))

                Circle()
                    .stroke(Color(hex: "FFB84A").opacity(0.18), lineWidth: 1.5)

                WelcomeAnimatedGIFView(
                    resourceCandidates: [
                        OnboardingMascotAsset.resourceName,
                        "bluealarm_blackbg"
                    ],
                    resourceExtension: "gif"
                )
                .frame(width: 148, height: 148)
                .clipShape(Circle())
            }
            .frame(width: 160, height: 160)
        }
        .opacity(mascotVisible ? 1 : 0)
        .scaleEffect(mascotVisible ? 1 : 0.88)
        .offset(y: mascotVisible ? (mascotBob ? -9 : 0) : 24)
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 3).repeatForever(autoreverses: true),
            value: mascotBob
        )
        .position(x: proxy.size.width / 2, y: proxy.size.height * 0.54)
        .accessibilityHidden(true)
    }

    private func morningCoachCard(in proxy: GeometryProxy) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(hex: "F5C87A"))

                Text("MORNING COACH")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .kerning(3)
                    .foregroundColor(Color(hex: "F0D8FF").opacity(0.76))
            }

            Text(typedSubline)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "F7EEFF"))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .frame(minHeight: 46)
                .accessibilityLabel(subline)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 16)
        .frame(width: proxy.size.width - 48)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(hex: "14082A").opacity(0.74))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color(hex: "B464DC").opacity(0.20), lineWidth: 1)
        )
        .shadow(color: Color(hex: "12051E").opacity(0.28), radius: 20, x: 0, y: 14)
        .opacity(sublineVisible ? 1 : 0)
        .offset(y: sublineVisible ? 0 : 12)
        .position(x: proxy.size.width / 2, y: proxy.size.height * 0.735)
    }

    private func bottomControls(in proxy: GeometryProxy) -> some View {
        VStack(spacing: 12) {
            Text("Quick setup · 2 min")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(Color(hex: "C89FE8").opacity(0.58))
                .opacity(metaVisible ? 1 : 0)

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onContinue()
            } label: {
                Text("Let's go")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.white)
                    .clipShape(Capsule())
            }
            .scaleEffect(ctaPulse ? 1.018 : 1.0)
            .opacity(ctaVisible ? 1 : 0)
            .offset(y: ctaVisible ? 0 : 18)
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 3).repeatForever(autoreverses: true),
                value: ctaPulse
            )
        }
        .padding(.horizontal, 24)
        .position(
            x: proxy.size.width / 2,
            y: proxy.size.height - max(proxy.safeAreaInsets.bottom, 8) - 62
        )
    }

    private func skipButton(in proxy: GeometryProxy) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onSkip()
        } label: {
            Text("Skip")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(Color(hex: "C8A8E0"))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .position(
            x: proxy.size.width - 48,
            y: proxy.safeAreaInsets.top + 36
        )
    }

    private func runEntranceAnimation() {
        guard !reduceMotion else {
            skyOpacity = 1
            starRevealCount = DuskStarSpec.all.count
            headlineVisible = true
            sublineVisible = true
            mascotVisible = true
            cloudsDrifting = false
            metaVisible = true
            ctaVisible = true
            mascotBob = false
            ctaPulse = false
            typedHeadline = headline
            typedSubline = subline
            return
        }

        withAnimation(.easeOut(duration: 0.7)) {
            skyOpacity = 1
        }

        for index in 0..<DuskStarSpec.all.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + Double(index) * 0.05) {
                starRevealCount = max(starRevealCount, index + 1)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(.spring(response: 0.78, dampingFraction: 0.78)) {
                headlineVisible = true
            }
            typeHeadline(startDelay: 0.12, characterDelay: 0.052, haptics: true)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.38) {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.72)) {
                mascotVisible = true
            }
            mascotBob = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            cloudsDrifting = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.45) {
            withAnimation(.easeOut(duration: 0.35)) {
                metaVisible = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.62) {
            withAnimation(.spring(response: 0.62, dampingFraction: 0.82)) {
                ctaVisible = true
            }
            ctaPulse = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.05) {
            withAnimation(.easeOut(duration: 0.5)) {
                sublineVisible = true
            }
            typeSubline(startDelay: 0.08, characterDelay: 0.042, haptics: true)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.85) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private func typeHeadline(startDelay: TimeInterval, characterDelay: TimeInterval, haptics: Bool) {
        type(headline, startDelay: startDelay, characterDelay: characterDelay, haptics: haptics) { value in
            typedHeadline = value
        }
    }

    private func typeSubline(startDelay: TimeInterval, characterDelay: TimeInterval, haptics: Bool) {
        type(subline, startDelay: startDelay, characterDelay: characterDelay, haptics: haptics) { value in
            typedSubline = value
        }
    }

    private func type(
        _ text: String,
        startDelay: TimeInterval,
        characterDelay: TimeInterval,
        haptics: Bool,
        assign: @escaping (String) -> Void
    ) {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()

        for offset in 0...text.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + startDelay + Double(offset) * characterDelay) {
                assign(String(text.prefix(offset)))

                if haptics, offset > 0, offset % 3 == 0 {
                    generator.selectionChanged()
                    generator.prepare()
                }
            }
        }
    }
}

struct DuskSkyView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let starRevealCount: Int
    let cloudsDrifting: Bool

    @State private var sunSinks = false
    @State private var horizonPulse = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                skyGradient

                clouds(in: proxy)
                sunsetAtmosphere(in: proxy)
                sun(in: proxy)
                stars(in: proxy)
                lowerThemeOverlay(in: proxy)
                bottomDarkOverlay
            }
            .onAppear {
                guard !reduceMotion else { return }
                sunSinks = true
                horizonPulse = true
            }
        }
    }

    private var skyGradient: some View {
        LinearGradient(
            stops: [
                .init(color: Color(hex: "0D0820"), location: 0.00),
                .init(color: Color(hex: "1A0D35"), location: 0.18),
                .init(color: Color(hex: "2D1458"), location: 0.32),
                .init(color: Color(hex: "36175E"), location: 0.46),
                .init(color: Color(hex: "552162"), location: 0.58),
                .init(color: Color(hex: "8F304E"), location: 0.70),
                .init(color: Color(hex: "BC5238"), location: 0.80),
                .init(color: Color(hex: "D98346"), location: 0.88),
                .init(color: Color(hex: "DFA65B"), location: 0.94),
                .init(color: Color(hex: "E7BD6B"), location: 1.00)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func sun(in proxy: GeometryProxy) -> some View {
        ZStack {
            Circle()
                .fill(Color(hex: "C76D31").opacity(0.18))
                .frame(width: 118, height: 118)
                .blur(radius: 22)

            Circle()
                .fill(Color(hex: "D99045").opacity(0.10))
                .frame(width: 92, height: 92)
                .blur(radius: 12)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "E8B96A"),
                            Color(hex: "D9893C"),
                            Color(hex: "B85A2D")
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 76, height: 76)
                .overlay(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.08),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                )
        }
            .offset(y: sunSinks ? 12 : 0)
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 8).repeatForever(autoreverses: true),
                value: sunSinks
            )
            .position(x: proxy.size.width / 2, y: proxy.size.height * 0.25)
    }

    private func sunsetAtmosphere(in proxy: GeometryProxy) -> some View {
        ZStack {
            Ellipse()
                .fill(Color(hex: "D87938").opacity(0.12))
                .frame(width: 360, height: 118)
                .blur(radius: 34)

            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "C56B34").opacity(0.12),
                            Color(hex: "8A3050").opacity(0.08),
                            Color.clear
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(width: 460, height: 170)
                .blur(radius: 28)
        }
            .scaleEffect(x: horizonPulse ? 1.08 : 1.0, y: 1.0, anchor: .center)
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 5).repeatForever(autoreverses: true),
                value: horizonPulse
            )
            .position(x: proxy.size.width / 2, y: proxy.size.height * 0.27)
    }

    private func lowerThemeOverlay(in proxy: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: proxy.size.height * 0.22)

            Rectangle()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color.clear, location: 0.00),
                            .init(color: Color(hex: "2B1450").opacity(0.26), location: 0.16),
                            .init(color: Color(hex: "180B30").opacity(0.58), location: 0.42),
                            .init(color: Color(hex: "0B0618").opacity(0.86), location: 0.76),
                            .init(color: Color(hex: "05030B").opacity(0.98), location: 1.00)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .frame(width: proxy.size.width, height: proxy.size.height)
    }

    private func stars(in proxy: GeometryProxy) -> some View {
        ZStack {
            ForEach(DuskStarSpec.all.indices, id: \.self) { index in
                DuskStarView(
                    spec: DuskStarSpec.all[index],
                    isRevealed: starRevealCount > index
                )
                .position(
                    x: proxy.size.width * DuskStarSpec.all[index].x,
                    y: proxy.size.height * DuskStarSpec.all[index].y
                )
            }
        }
    }

    private func clouds(in proxy: GeometryProxy) -> some View {
        ZStack {
            DuskCloudDrifter(
                spec: .init(
                    baseWidth: 65,
                    baseHeight: 18,
                    firstBump: 26,
                    secondBump: 20,
                    color: Color(hex: "B450A0").opacity(0.40),
                    yRatio: 0.16,
                    duration: 32,
                    movesLeftToRight: true,
                    initialProgress: 0.02
                ),
                isDrifting: cloudsDrifting
            )

            DuskCloudDrifter(
                spec: .init(
                    baseWidth: 48,
                    baseHeight: 14,
                    firstBump: 19,
                    secondBump: 15,
                    color: Color(hex: "8C3C82").opacity(0.35),
                    yRatio: 0.27,
                    duration: 40,
                    movesLeftToRight: false,
                    initialProgress: 0.72
                ),
                isDrifting: cloudsDrifting
            )

            DuskCloudDrifter(
                spec: .init(
                    baseWidth: 85,
                    baseHeight: 22,
                    firstBump: 34,
                    secondBump: 26,
                    color: Color(hex: "DC8250").opacity(0.25),
                    yRatio: 0.34,
                    duration: 28,
                    movesLeftToRight: true,
                    initialProgress: 0.42
                ),
                isDrifting: cloudsDrifting
            )

            DuskCloudDrifter(
                spec: .init(
                    baseWidth: 55,
                    baseHeight: 15,
                    firstBump: 22,
                    secondBump: 17,
                    color: Color(hex: "E8A050").opacity(0.20),
                    yRatio: 0.40,
                    duration: 36,
                    movesLeftToRight: false,
                    initialProgress: 0.18
                ),
                isDrifting: cloudsDrifting
            )
        }
        .frame(width: proxy.size.width, height: proxy.size.height)
    }

    private var bottomDarkOverlay: some View {
        VStack {
            Spacer()
            Rectangle()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color.clear, location: 0.00),
                            .init(color: Color(hex: "280E42").opacity(0.90), location: 0.70),
                            .init(color: Color(hex: "1A0A30"), location: 1.00)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 200)
        }
    }
}

private struct DuskStarSpec {
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let color: Color
    let duration: Double

    static let all: [DuskStarSpec] = [
        .init(x: 0.14, y: 0.03, size: 2.0, color: Color(hex: "FFFFFF"), duration: 2.8),
        .init(x: 0.47, y: 0.05, size: 1.5, color: Color(hex: "E8D0FF"), duration: 3.5),
        .init(x: 0.70, y: 0.02, size: 2.5, color: Color(hex: "FFFFFF"), duration: 2.2),
        .init(x: 0.24, y: 0.09, size: 1.0, color: Color(hex: "C8B0FF"), duration: 4.0),
        .init(x: 0.81, y: 0.04, size: 1.5, color: Color(hex: "FFFFFF"), duration: 3.1),
        .init(x: 0.57, y: 0.11, size: 1.0, color: Color(hex: "FFE8A0"), duration: 2.5),
        .init(x: 0.10, y: 0.07, size: 2.0, color: Color(hex: "FFD0A0"), duration: 3.8),
        .init(x: 0.88, y: 0.08, size: 1.0, color: Color(hex: "FFFFFF"), duration: 2.9),
        .init(x: 0.37, y: 0.17, size: 1.5, color: Color(hex: "E0CCFF"), duration: 3.3),
        .init(x: 0.74, y: 0.20, size: 1.0, color: Color(hex: "FFFFFF"), duration: 4.2),
        .init(x: 0.20, y: 0.22, size: 2.0, color: Color(hex: "FFF0C8"), duration: 2.6),
        .init(x: 0.62, y: 0.25, size: 1.0, color: Color(hex: "FFFFFF"), duration: 3.7),
        .init(x: 0.31, y: 0.04, size: 1.0, color: Color(hex: "FFFFFF"), duration: 3.0),
        .init(x: 0.92, y: 0.14, size: 1.6, color: Color(hex: "F4E6FF"), duration: 2.4),
        .init(x: 0.06, y: 0.18, size: 1.2, color: Color(hex: "FFFFFF"), duration: 3.9),
        .init(x: 0.51, y: 0.20, size: 1.8, color: Color(hex: "FFDFA8"), duration: 2.7),
        .init(x: 0.84, y: 0.24, size: 1.2, color: Color(hex: "FFFFFF"), duration: 3.4),
        .init(x: 0.42, y: 0.29, size: 1.0, color: Color(hex: "DCC8FF"), duration: 4.1),
        .init(x: 0.15, y: 0.32, size: 1.4, color: Color(hex: "FFFFFF"), duration: 2.9),
        .init(x: 0.79, y: 0.33, size: 1.0, color: Color(hex: "FFE8B8"), duration: 3.6),
        .init(x: 0.27, y: 0.39, size: 1.0, color: Color(hex: "F8EFFF"), duration: 4.4),
        .init(x: 0.69, y: 0.38, size: 1.4, color: Color(hex: "FFFFFF"), duration: 2.8),
        .init(x: 0.94, y: 0.29, size: 1.0, color: Color(hex: "EBD8FF"), duration: 3.2),
        .init(x: 0.04, y: 0.42, size: 1.2, color: Color(hex: "FFFFFF"), duration: 3.5)
    ]
}

private struct DuskStarView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let spec: DuskStarSpec
    let isRevealed: Bool

    @State private var twinkle = false

    var body: some View {
        Circle()
            .fill(spec.color)
            .frame(width: spec.size, height: spec.size)
            .opacity(opacity)
            .shadow(color: spec.color.opacity(0.55), radius: spec.size * 1.8)
            .animation(
                reduceMotion ? nil : .easeInOut(duration: spec.duration).repeatForever(autoreverses: true),
                value: twinkle
            )
            .onAppear {
                guard !reduceMotion else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + spec.duration.truncatingRemainder(dividingBy: 1.2)) {
                    twinkle = true
                }
            }
    }

    private var opacity: Double {
        guard isRevealed else { return 0 }
        if reduceMotion { return 0.55 }
        return twinkle ? 0.90 : 0.10
    }
}

private struct DuskCloudSpec {
    let baseWidth: CGFloat
    let baseHeight: CGFloat
    let firstBump: CGFloat
    let secondBump: CGFloat
    let color: Color
    let yRatio: CGFloat
    let duration: Double
    let movesLeftToRight: Bool
    let initialProgress: CGFloat
}

private struct DuskCloudDrifter: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let spec: DuskCloudSpec
    let isDrifting: Bool

    var body: some View {
        GeometryReader { proxy in
            DuskCloudShapeView(spec: spec)
                .position(x: xPosition(width: proxy.size.width), y: proxy.size.height * spec.yRatio)
                .animation(
                    reduceMotion ? nil : .linear(duration: spec.duration).repeatForever(autoreverses: false),
                    value: isDrifting
                )
        }
    }

    private func xPosition(width: CGFloat) -> CGFloat {
        guard !reduceMotion else {
            return width * (0.2 + spec.initialProgress * 0.6)
        }

        let start = spec.movesLeftToRight ? -90.0 : width + 90.0
        let end = spec.movesLeftToRight ? width + 90.0 : -90.0
        if isDrifting {
            return end
        }
        return start + (end - start) * spec.initialProgress
    }
}

private struct DuskCloudShapeView: View {
    let spec: DuskCloudSpec

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Capsule()
                .fill(spec.color)
                .frame(width: spec.baseWidth, height: spec.baseHeight)
                .offset(x: 0, y: spec.baseHeight * 0.45)

            Circle()
                .fill(spec.color)
                .frame(width: spec.firstBump, height: spec.firstBump)
                .offset(x: spec.baseWidth * 0.22, y: -spec.firstBump * 0.15)

            Circle()
                .fill(spec.color)
                .frame(width: spec.secondBump, height: spec.secondBump)
                .offset(x: spec.baseWidth * 0.52, y: -spec.secondBump * 0.08)
        }
        .frame(width: spec.baseWidth, height: spec.baseHeight + max(spec.firstBump, spec.secondBump) * 0.72)
        .blur(radius: 0.2)
    }
}

private struct WelcomeAnimatedGIFView: UIViewRepresentable {
    let resourceCandidates: [String]
    let resourceExtension: String

    func makeUIView(context: Context) -> WelcomeStreamingGIFView {
        let container = WelcomeStreamingGIFView()
        container.configure(resourceCandidates: resourceCandidates, resourceExtension: resourceExtension)
        return container
    }

    func updateUIView(_ uiView: WelcomeStreamingGIFView, context: Context) {
        uiView.configure(resourceCandidates: resourceCandidates, resourceExtension: resourceExtension)
    }

    static func dismantleUIView(_ uiView: WelcomeStreamingGIFView, coordinator: ()) {
        uiView.stop()
    }
}

private final class WelcomeStreamingGIFView: UIView {
    private let imageView = UIImageView()
    private var displayLink: CADisplayLink?
    private var source: CGImageSource?
    private var frameDurations: [TimeInterval] = []
    private var currentFrameIndex = 0
    private var accumulatedFrameTime: TimeInterval = 0
    private var previousTimestamp: CFTimeInterval = 0
    private var resourceIdentifier: String?
    private var currentMaxPixelSize = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    deinit {
        stop()
    }

    func configure(resourceCandidates: [String], resourceExtension: String) {
        guard let resourceName = resourceCandidates.first(where: {
            Bundle.main.url(forResource: $0, withExtension: resourceExtension) != nil
        }) else {
            stop()
            imageView.image = nil
            resourceIdentifier = nil
            return
        }

        let identifier = "\(resourceName).\(resourceExtension)"
        guard identifier != resourceIdentifier else {
            startIfNeeded()
            return
        }

        stop()
        resourceIdentifier = identifier
        source = nil
        frameDurations = []
        currentFrameIndex = 0
        accumulatedFrameTime = 0
        previousTimestamp = 0
        imageView.image = nil

        guard let url = Bundle.main.url(forResource: resourceName, withExtension: resourceExtension),
              let gifSource = CGImageSourceCreateWithURL(url as CFURL, [
                kCGImageSourceShouldCache: false
              ] as CFDictionary) else {
            return
        }

        source = gifSource
        let frameCount = CGImageSourceGetCount(gifSource)
        guard frameCount > 0 else { return }
        frameDurations = (0..<frameCount).map { Self.frameDuration(from: gifSource, at: $0) }
        displayFrame(at: 0)
        startIfNeeded()
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        previousTimestamp = 0
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let newMaxPixelSize = max(1, Int(ceil(max(bounds.width, bounds.height) * traitCollection.displayScale)))
        if abs(newMaxPixelSize - currentMaxPixelSize) > 8 {
            currentMaxPixelSize = newMaxPixelSize
            displayFrame(at: currentFrameIndex)
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        window == nil ? stop() : startIfNeeded()
    }

    private func setupView() {
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.backgroundColor = .clear
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        clipsToBounds = true
        backgroundColor = .clear
    }

    private func startIfNeeded() {
        guard displayLink == nil, source != nil, !frameDurations.isEmpty, window != nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(stepFrame(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func stepFrame(_ link: CADisplayLink) {
        guard let source, !frameDurations.isEmpty else { return }
        if previousTimestamp == 0 {
            previousTimestamp = link.timestamp
            return
        }

        accumulatedFrameTime += link.timestamp - previousTimestamp
        previousTimestamp = link.timestamp

        let duration = frameDurations[currentFrameIndex]
        guard accumulatedFrameTime >= duration else { return }

        accumulatedFrameTime = 0
        currentFrameIndex = (currentFrameIndex + 1) % CGImageSourceGetCount(source)
        displayFrame(at: currentFrameIndex)
    }

    private func displayFrame(at index: Int) {
        guard let source else { return }
        let maxPixelSize = max(currentMaxPixelSize, Int(ceil(max(bounds.width, bounds.height) * max(traitCollection.displayScale, 1))))
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false,
            kCGImageSourceShouldCacheImmediately: false,
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, index, options as CFDictionary)
            ?? CGImageSourceCreateImageAtIndex(source, index, [
                kCGImageSourceShouldCache: false
            ] as CFDictionary) else {
            return
        }
        imageView.image = UIImage(cgImage: cgImage, scale: max(traitCollection.displayScale, 1), orientation: .up)
    }

    private static func frameDuration(from source: CGImageSource, at index: Int) -> TimeInterval {
        let defaultDuration = 0.06
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
              let gifProperties = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any] else {
            return defaultDuration
        }

        let unclamped = gifProperties[kCGImagePropertyGIFUnclampedDelayTime] as? Double
        let clamped = gifProperties[kCGImagePropertyGIFDelayTime] as? Double
        let duration = unclamped ?? clamped ?? defaultDuration
        return duration < 0.011 ? defaultDuration : duration
    }
}

private struct iOSSpeechBubbleShape: Shape {
    let cornerRadius: CGFloat
    let tailWidth: CGFloat
    let tailHeight: CGFloat
    let tailOffset: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let w = rect.width
        let h = rect.height
        let r = min(cornerRadius, min(w / 2, h / 2))
        
        let tailCenterX = rect.midX + tailOffset
        let tailStart = tailCenterX - tailWidth / 2
        let tailEnd = tailCenterX + tailWidth / 2
        
        path.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
        
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        path.addArc(
            center: CGPoint(x: rect.maxX - r, y: rect.minY + r),
            radius: r,
            startAngle: Angle(degrees: -90),
            endAngle: Angle(degrees: 0),
            clockwise: false
        )
        
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addArc(
            center: CGPoint(x: rect.maxX - r, y: rect.maxY - r),
            radius: r,
            startAngle: Angle(degrees: 0),
            endAngle: Angle(degrees: 90),
            clockwise: false
        )
        
        path.addLine(to: CGPoint(x: tailEnd, y: rect.maxY))
        
        let tip = CGPoint(x: tailCenterX + 2, y: rect.maxY + tailHeight)
        let control1 = CGPoint(
            x: tailEnd - (tailWidth * 0.15),
            y: rect.maxY + (tailHeight * 0.45)
        )
        path.addQuadCurve(to: tip, control: control1)
        
        let control2 = CGPoint(
            x: tailStart + (tailWidth * 0.2),
            y: rect.maxY + (tailHeight * 0.4)
        )
        path.addQuadCurve(to: CGPoint(x: tailStart, y: rect.maxY), control: control2)
        
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        
        path.addArc(
            center: CGPoint(x: rect.minX + r, y: rect.maxY - r),
            radius: r,
            startAngle: Angle(degrees: 90),
            endAngle: Angle(degrees: 180),
            clockwise: false
        )
        
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        path.addArc(
            center: CGPoint(x: rect.minX + r, y: rect.minY + r),
            radius: r,
            startAngle: Angle(degrees: 180),
            endAngle: Angle(degrees: 270),
            clockwise: false
        )
        
        path.closeSubpath()
        return path
    }
}

#Preview {
    WelcomeView(
        onContinue: {},
        onSkip: {}
    )
}
