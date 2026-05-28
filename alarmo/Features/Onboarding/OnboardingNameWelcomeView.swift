import SwiftUI

struct OnboardingNameWelcomeView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    var isMascotHidden = false
    let onNext: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAdvancing = false
    @State private var didRevealCopy = false
    @State private var isMascotBreathing = false
    @State private var mascotRevealProgress: CGFloat = 0
    @State private var mascotFlightProgress: CGFloat = 0

    private var isTiimoTheme: Bool {
        AlarmThemeStyle.persisted.usesTiimoLayoutBranch
    }

    private var welcomeCopyTopSpacing: CGFloat {
        isTiimoTheme ? 142 : 110
    }

    var body: some View {
        GeometryReader { proxy in
            let currentMascotSize = mascotSize(in: proxy)
            ZStack(alignment: .topLeading) {
                if isTiimoTheme {
                    AnimatedSkyView()
                } else {
                    Colors.bgPrimary.ignoresSafeArea()
                    NameWelcomeNightSkyAccent()
                        .ignoresSafeArea()
                }

                VStack(spacing: 0) {
                    Spacer().frame(height: welcomeCopyTopSpacing)

                    Text("Welcome, \(viewModel.displayFirstName)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(Colors.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.l)
                        .opacity(didRevealCopy ? 1 : 0)
                        .offset(y: didRevealCopy ? 0 : 16)
                        .animation(.spring(response: 0.62, dampingFraction: 0.82), value: didRevealCopy)

                    Text("Let's make your mornings feel better.")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 10)
                        .padding(.horizontal, Spacing.l)
                        .opacity(didRevealCopy ? 1 : 0)
                        .offset(y: didRevealCopy ? 0 : 12)
                        .animation(.spring(response: 0.62, dampingFraction: 0.82).delay(0.08), value: didRevealCopy)

                    Spacer()
                }
                .onboardingContentFrame()
                .frame(width: proxy.size.width, height: proxy.size.height)

                ZStack {
                    WelcomeMascotSpotlight()
                        .frame(width: currentMascotSize * 1.05, height: currentMascotSize * 0.62)
                        .offset(y: currentMascotSize * 0.33)
                        .opacity(spotlightOpacity)
                        .scaleEffect(0.78 + 0.22 * mascotRevealProgress)

                    AnimatedGIFView(resourceName: OnboardingMascotAsset.resourceName, resourceExtension: "gif")
                        .frame(width: currentMascotSize, height: currentMascotSize)
                }
                    .frame(width: currentMascotSize, height: currentMascotSize)
                    .position(mascotPosition(in: proxy))
                    .opacity(mascotOpacity)
                    .scaleEffect(mascotScale)
                    .rotationEffect(.degrees(mascotRotationDegrees))
                    .blur(radius: mascotBlur)
                    .offset(y: mascotVerticalOffset)
                    .animation(.spring(response: 0.72, dampingFraction: 0.78), value: mascotRevealProgress)
                    .animation(.spring(response: 0.62, dampingFraction: 0.86), value: mascotFlightProgress)
                    .animation(.easeInOut(duration: 2.35).repeatForever(autoreverses: true), value: isMascotBreathing)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: OnboardingWelcomeMascotFramePreferenceKey.self,
                                value: geo.frame(in: .named(OnboardingMascotFlightCoordinateSpace.name))
                            )
                        }
                    )
                    .zIndex(10)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "Continue", style: .blueGlass) {
                advanceWithAnimation()
            }
            .padding(.horizontal, Spacing.l)
            .padding(.bottom, Spacing.m)
            .disabled(isAdvancing)
            .opacity(isAdvancing ? 0.7 : 1.0)
        }
        .onAppear {
            isAdvancing = false
            mascotFlightProgress = 0
            runEntranceAnimation()
        }
    }

    private func introMascotBaseSize(in proxy: GeometryProxy) -> CGFloat {
        // Keep exactly the same base size logic as the first onboarding intro screen.
        min(proxy.size.width * 0.493, 202)
    }

    private func mascotSize(in proxy: GeometryProxy) -> CGFloat {
        lerp(from: introMascotBaseSize(in: proxy), to: 64, progress: mascotFlightProgress)
    }

    private func mascotPosition(in proxy: GeometryProxy) -> CGPoint {
        let start = mascotStartPosition(in: proxy)
        let target = mascotTargetPosition(in: proxy)
        return CGPoint(
            x: lerp(from: start.x, to: target.x, progress: mascotFlightProgress),
            y: lerp(from: start.y, to: target.y, progress: mascotFlightProgress)
        )
    }

    private var mascotOpacity: Double {
        guard !isMascotHidden else { return 0 }
        return Double(mascotRevealProgress)
    }

    private var spotlightOpacity: Double {
        guard !isMascotHidden else { return 0 }
        return Double(0.2 + (0.8 * mascotRevealProgress))
    }

    private var mascotScale: CGFloat {
        guard mascotFlightProgress < 0.001 else { return 1 }
        guard !reduceMotion else { return 1 }
        let settledScale = lerp(from: 0.86, to: 1.0, progress: mascotRevealProgress)
        return isMascotBreathing ? settledScale * 1.012 : settledScale * 0.995
    }

    private var mascotVerticalOffset: CGFloat {
        guard mascotFlightProgress < 0.001 else { return 0 }
        guard !reduceMotion else { return 0 }
        let settleOffset = lerp(from: 22, to: 0, progress: mascotRevealProgress)
        return isMascotBreathing ? settleOffset - 4 : settleOffset + 1
    }

    private var mascotRotationDegrees: Double {
        guard mascotFlightProgress < 0.001, mascotRevealProgress > 0.95, !reduceMotion else { return 0 }
        return isMascotBreathing ? -1.2 : 1.0
    }

    private var mascotBlur: CGFloat {
        guard !reduceMotion else { return 0 }
        return max(0, (1 - mascotRevealProgress) * 4.5)
    }

    private func mascotStartPosition(in proxy: GeometryProxy) -> CGPoint {
        CGPoint(x: proxy.size.width * 0.5, y: proxy.size.height * 0.58)
    }

    private func mascotTargetPosition(in proxy: GeometryProxy) -> CGPoint {
        // Matches the questionary header GIF: padding-top 20 + half of 64pt GIF = 52pt from content top.
        // X mirrors the right-aligned 64pt icon with Spacing.l (24pt) right padding.
        CGPoint(x: proxy.size.width - Spacing.l - 32, y: 52)
    }

    private func advanceWithAnimation() {
        guard !isAdvancing else { return }
        isAdvancing = true
        isMascotBreathing = false
        withAnimation(.spring(response: 0.58, dampingFraction: 0.84)) {
            mascotFlightProgress = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.39) {
            onNext()
        }
    }

    private func runEntranceAnimation() {
        didRevealCopy = false
        isMascotBreathing = false
        mascotRevealProgress = 0
        mascotFlightProgress = 0

        if reduceMotion {
            didRevealCopy = true
            mascotRevealProgress = 1
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            didRevealCopy = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
            withAnimation(.spring(response: 0.72, dampingFraction: 0.78)) {
                mascotRevealProgress = 1
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
            isMascotBreathing = true
        }
    }

    private func lerp(from: CGFloat, to: CGFloat, progress: CGFloat) -> CGFloat {
        from + (to - from) * progress
    }
}

private struct WelcomeMascotSpotlight: View {
    var body: some View {
        ZStack {
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 255 / 255, green: 197 / 255, blue: 111 / 255).opacity(0.22),
                            Color(red: 255 / 255, green: 197 / 255, blue: 111 / 255).opacity(0)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 120
                    )
                )

            Ellipse()
                .fill(Color.white.opacity(0.32))
                .frame(width: 178, height: 44)
                .blur(radius: 14)
                .offset(y: 22)
        }
    }
}

private struct NameWelcomeNightSkyAccent: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let accentHeight = proxy.size.height * 0.28

            ZStack(alignment: .topLeading) {
                LinearGradient(
                    stops: [
                        .init(color: Color(hex: "0D0820").opacity(0.92), location: 0.00),
                        .init(color: Color(hex: "1A0D35").opacity(0.74), location: 0.36),
                        .init(color: Color(hex: "2D1458").opacity(0.34), location: 0.70),
                        .init(color: Color.clear, location: 1.00)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: proxy.size.width, height: accentHeight)

                ForEach(NameWelcomeStarSpec.all.indices, id: \.self) { index in
                    NameWelcomeStarView(
                        spec: NameWelcomeStarSpec.all[index],
                        delay: Double(index) * 0.22
                    )
                    .position(
                        x: proxy.size.width * NameWelcomeStarSpec.all[index].x,
                        y: accentHeight * NameWelcomeStarSpec.all[index].y
                    )
                }

                Ellipse()
                    .fill(Color(hex: "F2A862").opacity(0.08))
                    .frame(width: proxy.size.width * 0.92, height: accentHeight * 0.44)
                    .blur(radius: 22)
                    .position(x: proxy.size.width * 0.5, y: accentHeight * 0.88)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            .allowsHitTesting(false)
        }
    }
}

private struct NameWelcomeStarSpec {
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let color: Color
    let duration: Double

    static let all: [NameWelcomeStarSpec] = [
        .init(x: 0.10, y: 0.12, size: 1.4, color: Color(hex: "FFFFFF"), duration: 2.9),
        .init(x: 0.22, y: 0.28, size: 1.0, color: Color(hex: "E8D0FF"), duration: 3.6),
        .init(x: 0.37, y: 0.16, size: 1.7, color: Color(hex: "FFF0C8"), duration: 2.5),
        .init(x: 0.55, y: 0.10, size: 1.1, color: Color(hex: "FFFFFF"), duration: 4.0),
        .init(x: 0.72, y: 0.24, size: 1.5, color: Color(hex: "DCC8FF"), duration: 3.1),
        .init(x: 0.88, y: 0.13, size: 1.0, color: Color(hex: "FFFFFF"), duration: 2.7),
        .init(x: 0.16, y: 0.48, size: 1.2, color: Color(hex: "FFDFA8"), duration: 3.8),
        .init(x: 0.47, y: 0.38, size: 1.0, color: Color(hex: "FFFFFF"), duration: 3.3),
        .init(x: 0.81, y: 0.46, size: 1.3, color: Color(hex: "F8EFFF"), duration: 4.2),
        .init(x: 0.64, y: 0.58, size: 1.0, color: Color(hex: "FFFFFF"), duration: 2.8)
    ]
}

private struct NameWelcomeStarView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let spec: NameWelcomeStarSpec
    let delay: Double

    @State private var isBright = false

    var body: some View {
        Circle()
            .fill(spec.color)
            .frame(width: spec.size, height: spec.size)
            .opacity(reduceMotion ? 0.48 : (isBright ? 0.92 : 0.14))
            .shadow(color: spec.color.opacity(0.46), radius: spec.size * 1.8)
            .animation(
                reduceMotion ? nil : .easeInOut(duration: spec.duration).repeatForever(autoreverses: true),
                value: isBright
            )
            .onAppear {
                guard !reduceMotion else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    isBright = true
                }
            }
    }
}
