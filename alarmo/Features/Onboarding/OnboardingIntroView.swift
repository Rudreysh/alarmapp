import SwiftUI
import UIKit
import ImageIO
import Combine

struct OnboardingIntroView: View {
    let onNext: () -> Void
    var onSkip: (() -> Void)? = nil
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var currentPage = 0
    @State private var gifRenderNonce = 0
    @State private var pageIntroRevealIndex = 0
    @State private var typedText = ""
    @State private var typedCaption = ""
    @State private var morningCoachSectionHeight: CGFloat = 0
    @State private var typingTimer: AnyCancellable?
    @State private var captionTypingTimer: AnyCancellable?
    private let introMainText = "Hey! I'm your alarm."
    private let introCaptionText = "I'll help you stop snoozing through the morning."
    private let typingSelectionFeedback = UISelectionFeedbackGenerator()
    private let typingImpactFeedback = UIImpactFeedbackGenerator(style: .soft)

    
    private var isTiimoTheme: Bool {
        AlarmThemeStyle.persisted.usesTiimoLayoutBranch
    }

    var body: some View {
        ZStack {
            Colors.bgPrimary
                .ignoresSafeArea()
                
            if currentPage == 0 && isTiimoTheme {
                AnimatedSkyView()
            }

            VStack(spacing: 0) {
                pageIntro

                Spacer()
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    Text("Quick setup · 2 min")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Colors.textTertiary)

                    PrimaryButton(title: "Let's go", style: .blueGlass) {
                        onNext()
                    }
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, 48)
                .opacity(!isTiimoTheme || pageIntroRevealIndex >= 3 ? 1 : 0)
                .offset(y: !isTiimoTheme || pageIntroRevealIndex >= 3 ? 0 : 10)
                .animation(.spring(response: 0.58, dampingFraction: 0.84), value: pageIntroRevealIndex)
            }

            if let onSkip = onSkip {
                VStack {
                    HStack {
                        Spacer()
                        Button("Skip") {
                            onSkip()
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isTiimoTheme ? .black : Colors.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    Spacer()
                }
                .padding(.top, 4)
                .ignoresSafeArea(edges: .top)
                .zIndex(50)
            }
        }
        .onChange(of: currentPage) { _, newPage in
            // TabView may recycle/detach the first page view and leave GIF playback stopped.
            // Force a remount whenever user comes back to page 0 so animation always restarts.
            if newPage == 0 {
                gifRenderNonce += 1
            }
            if newPage == 0 {
                runIntroSequence()
            }
        }
        .onAppear {
            if isTiimoTheme {
                runIntroSequence()
            }
        }
        .onDisappear {
            typingTimer?.cancel()
            captionTypingTimer?.cancel()
        }
    }

    private func runIntroSequence() {
        guard isTiimoTheme else { return }
        pageIntroRevealIndex = 0
        startTypingEffect()

        if reduceMotion {
            pageIntroRevealIndex = 3
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { pageIntroRevealIndex = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.78) { pageIntroRevealIndex = 2 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.90) { pageIntroRevealIndex = 3 }
    }
    
    private func startTypingEffect() {
        typedText = ""
        typedCaption = ""
        typingTimer?.cancel()
        captionTypingTimer?.cancel()
        if reduceMotion {
            typedText = introMainText
            typedCaption = introCaptionText
            return
        }

        typingSelectionFeedback.prepare()
        typingImpactFeedback.prepare()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.92) {
            var charIndex = 0
            let chars = Array(introMainText)
            typingTimer = Timer.publish(every: 0.06, on: .main, in: .common)
                .autoconnect()
                .sink { _ in
                    if charIndex < chars.count {
                        let nextCharacter = chars[charIndex]
                        typedText.append(nextCharacter)
                        emitTypingFeedback(for: nextCharacter, index: charIndex, cadence: 2)
                        charIndex += 1
                    } else {
                        emitTypingCompletionFeedback()
                        typingTimer?.cancel()
                    }
                }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.04) {
            var charIndex = 0
            let chars = Array(introCaptionText)
            captionTypingTimer = Timer.publish(every: 0.045, on: .main, in: .common)
                .autoconnect()
                .sink { _ in
                    if charIndex < chars.count {
                        let nextCharacter = chars[charIndex]
                        typedCaption.append(nextCharacter)
                        emitTypingFeedback(for: nextCharacter, index: charIndex, cadence: 3)
                        charIndex += 1
                    } else {
                        emitTypingCompletionFeedback()
                        captionTypingTimer?.cancel()
                    }
                }
        }
    }

    private func emitTypingFeedback(for character: Character, index: Int, cadence: Int) {
        guard character.isLetter || character.isNumber else { return }
        guard index.isMultiple(of: cadence) else { return }
        typingSelectionFeedback.selectionChanged()
        typingSelectionFeedback.prepare()
    }

    private func emitTypingCompletionFeedback() {
        typingImpactFeedback.impactOccurred(intensity: 0.6)
        typingImpactFeedback.prepare()
    }
    // MARK: - Pages

    private var pageIntro: some View {
        GeometryReader { proxy in
            if isTiimoTheme {
                tiimoIntroContent(in: proxy)
            } else {
                defaultIntroContent(in: proxy)
            }
        }
    }

    private func tiimoIntroContent(in proxy: GeometryProxy) -> some View {
        let mascotSize = min(proxy.size.width * 0.493, 202)
        let topSpacing = max(88, min(124, proxy.size.height * 0.16))
        let introBlockDownwardOffset = (morningCoachSectionHeight > 0 ? morningCoachSectionHeight : 110) * 0.7

        return VStack(spacing: 0) {
            Spacer().frame(height: topSpacing)

            VStack(spacing: 0) {
                AlarmSpeechBubble(
                    typedText: typedText,
                    isTyping: pageIntroRevealIndex >= 2 && typedText != introMainText
                )
                    .padding(.horizontal, Spacing.l)
                    .opacity(pageIntroRevealIndex >= 2 ? 1 : 0)
                    .offset(y: pageIntroRevealIndex >= 2 ? 0 : 12)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: pageIntroRevealIndex)

                Spacer().frame(height: 12)

                ZStack {
                    MascotLandingGlow()
                        .frame(width: mascotSize * 0.92, height: mascotSize * 0.5)
                        .offset(y: mascotSize * 0.32)

                    AnimatedGIFView(resourceName: OnboardingMascotAsset.resourceName, resourceExtension: "gif")
                        .frame(width: mascotSize, height: mascotSize)
                        .id("intro-gif-\(gifRenderNonce)")
                }
                .frame(width: mascotSize, height: mascotSize + 14)
                .opacity(pageIntroRevealIndex >= 1 ? 1 : 0)
                .scaleEffect(pageIntroRevealIndex >= 1 ? 1 : 0.86)
                .blur(radius: pageIntroRevealIndex >= 1 ? 0 : 5)
                .offset(y: pageIntroRevealIndex >= 1 ? 0 : 22)
                .animation(.spring(response: 0.72, dampingFraction: 0.72), value: pageIntroRevealIndex)

                Spacer().frame(height: 16)

                AlarmTypedCaption(text: typedCaption)
                    .padding(.horizontal, Spacing.l)
                    .opacity(pageIntroRevealIndex >= 3 ? 1 : 0)
                    .offset(y: pageIntroRevealIndex >= 3 ? 0 : 10)
                    .animation(.spring(response: 0.58, dampingFraction: 0.84), value: pageIntroRevealIndex)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: OnboardingIntroMorningCoachHeightPreferenceKey.self,
                                value: geo.size.height
                            )
                        }
                    )
            }
            .offset(y: introBlockDownwardOffset)

            Spacer(minLength: 0)
        }
        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        .onPreferenceChange(OnboardingIntroMorningCoachHeightPreferenceKey.self) { newHeight in
            guard newHeight > 0 else { return }
            morningCoachSectionHeight = newHeight
        }
    }

    private func defaultIntroContent(in proxy: GeometryProxy) -> some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer().frame(height: 110)

                Text("Hey! I'm your alarm.")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundColor(Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.l)
                    .padding(.bottom, 20)

                Text("I'll help you stop snoozing through the morning.")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Colors.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
                    .padding(.horizontal, Spacing.l)

                Spacer()
            }

            AnimatedGIFView(resourceName: OnboardingMascotAsset.resourceName, resourceExtension: "gif")
                .frame(width: 252, height: 252)
                .id("intro-gif-\(gifRenderNonce)")
                .position(x: proxy.size.width * 0.5, y: proxy.size.height * 0.58)
        }
    }

    private var pageOne: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    header(title: "Master your time.", subtitle: "Alarms, habits and focus in one unified workspace.")
                    ZStack {
                        Circle()
                            .fill(Colors.cardSurface)
                            .frame(width: 34, height: 34)
                        Image(systemName: "alarm.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Colors.accentTeal)
                    }
                    .overlay(
                        Circle()
                            .stroke(Colors.cardStroke, lineWidth: 1)
                    )
                    .padding(.top, Spacing.m)
                    .padding(.trailing, Spacing.l)
                }

                IntroFeatureCarousel(
                    slides: [
                        IntroFeatureSlide(icon: "alarm.fill", accent: Colors.accentTeal, title: "Smart Alarms", subtitle: "Wake up reliably with alarm missions and louder fallback options."),
                        IntroFeatureSlide(icon: "timer", accent: .orange, title: "Pomodoro", subtitle: "Stay in deep focus with clean countdown sessions."),
                        IntroFeatureSlide(icon: "chart.xyaxis.line", accent: Colors.accentBlue, title: "Progress Reports", subtitle: "Track daily and weekly consistency at a glance.")
                    ]
                )
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.l)
                .padding(.bottom, Spacing.xl)
            }
        }
    }
    
    private var pageTwo: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                header(title: "Deep Work, Simplified.", subtitle: "Stay focused with app blocking and coordinate better with time overlap.")
                IntroFeatureCarousel(
                    slides: [
                        IntroFeatureSlide(icon: "shield.lefthalf.filled", accent: .orange, title: "App Blocking", subtitle: "Block distracting apps during focus sessions and alarm missions."),
                        IntroFeatureSlide(icon: "quote.bubble.fill", accent: Colors.accentTeal, title: "Motivation Quotes", subtitle: "Start mornings with the right mindset and momentum."),
                        IntroFeatureSlide(icon: "target", accent: Colors.accentBlue, title: "Wake Missions", subtitle: "Complete tasks to stop snoozing and get out of bed.")
                    ]
                )
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.xl)
                .padding(.bottom, Spacing.xxl)
            }
        }
    }
    
    // Header Builder
    private func header(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundColor(Colors.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            Text(subtitle)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Colors.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.l)
        .padding(.top, Spacing.m)
    }
    
}

private struct IntroFeatureSlide: Identifiable {
    let id = UUID()
    let icon: String
    let accent: Color
    let title: String
    let subtitle: String
}

private struct OnboardingIntroMorningCoachHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct AlarmSpeechBubble: View {
    let typedText: String
    let isTyping: Bool

    var body: some View {
        Text(typedText.isEmpty ? " " : typedText)
            .font(.system(size: 19, weight: .bold, design: .rounded))
            .foregroundColor(Color(hex: "#1A1A1A"))
            .lineLimit(2)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .center)
            .background(
                iOSSpeechBubbleShape(cornerRadius: 22, tailWidth: 28, tailHeight: 14, tailOffset: 48)
                    .fill(Color.white.opacity(0.94))
                    .background(Color.white.opacity(0.12))
                    .clipShape(iOSSpeechBubbleShape(cornerRadius: 22, tailWidth: 28, tailHeight: 14, tailOffset: 48))
            )
            .overlay(
                iOSSpeechBubbleShape(cornerRadius: 22, tailWidth: 28, tailHeight: 14, tailOffset: 48)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.95),
                                Color(hex: "#F0EFFE").opacity(0.85)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            )
            .shadow(color: Color.black.opacity(0.07), radius: 18, x: 0, y: 10)
    }
}

private struct AlarmTypedCaption: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let text: String
    @State private var cursorVisible = false

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(Color(hex: "#F6B44B"))

                Text("MORNING COACH")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .tracking(1.0)
                    .foregroundColor(Color(hex: "#9A8D79"))
            }

            HStack(alignment: .lastTextBaseline, spacing: 5) {
                Text(text.isEmpty ? " " : text)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#3E3A4E"))
                    .lineSpacing(4)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(Color(hex: "#7F77DD").opacity(0.9))
                    .frame(width: 2.5, height: 16)
                    .opacity(reduceMotion ? 1 : (cursorVisible ? 1 : 0.18))
                    .animation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true), value: cursorVisible)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
        .frame(maxWidth: 330)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.95),
                            Color(hex: "#F3E7D4").opacity(0.78)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
        .shadow(color: Color(hex: "#B8945C").opacity(0.12), radius: 20, x: 0, y: 10)
        .onAppear {
            cursorVisible = true
        }
    }
}

private struct MascotLandingGlow: View {
    var body: some View {
        ZStack {
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 255 / 255, green: 183 / 255, blue: 92 / 255).opacity(0.25),
                            Color(red: 255 / 255, green: 183 / 255, blue: 92 / 255).opacity(0)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 95
                    )
                )

            Ellipse()
                .fill(Color.white.opacity(0.24))
                .frame(width: 150, height: 42)
                .blur(radius: 13)
                .offset(y: 26)
        }
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

private struct IntroFeatureCarousel: View {
    let slides: [IntroFeatureSlide]
    @State private var selectedIndex = 0
    private let timer = Timer.publish(every: 2.6, on: .main, in: .common).autoconnect()

    var body: some View {
        TabView(selection: $selectedIndex) {
            ForEach(Array(slides.enumerated()), id: \.offset) { index, slide in
                IntroFeatureCard(slide: slide)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 260)
        .onReceive(timer) { _ in
            guard slides.count > 1 else { return }
            withAnimation(.easeInOut(duration: 0.4)) {
                selectedIndex = (selectedIndex + 1) % slides.count
            }
        }
    }
}

private struct IntroFeatureCard: View {
    let slide: IntroFeatureSlide

    var body: some View {
        HStack(spacing: Spacing.m) {
            VStack(alignment: .leading, spacing: Spacing.s) {
                ZStack {
                    Circle()
                        .fill(slide.accent.opacity(0.18))
                        .frame(width: 52, height: 52)
                    Image(systemName: slide.icon)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(slide.accent)
                }

                Text(slide.title)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundColor(Colors.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)

                Text(slide.subtitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Colors.textSecondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                Circle()
                    .fill(slide.accent.opacity(0.16))
                    .frame(width: 118, height: 118)
                Image(systemName: slide.icon)
                    .font(.system(size: 50, weight: .semibold))
                    .foregroundColor(slide.accent)
            }
        }
        .padding(Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 248)
        .background(
            RoundedRectangle(cornerRadius: Radii.card, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Colors.cardSurface.opacity(0.96),
                            Colors.bgSecondary.opacity(0.96)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radii.card, style: .continuous)
                .stroke(Colors.cardStroke, lineWidth: 1)
        )
        .appShadow(Shadows.card)
    }
}

struct AnimatedGIFView: UIViewRepresentable {
    let resourceName: String
    let resourceExtension: String

    func makeUIView(context: Context) -> StreamingGIFContainerView {
        let container = StreamingGIFContainerView()
        container.configure(resourceName: resourceName, resourceExtension: resourceExtension)
        return container
    }

    func updateUIView(_ uiView: StreamingGIFContainerView, context: Context) {
        uiView.configure(resourceName: resourceName, resourceExtension: resourceExtension)
    }

    static func dismantleUIView(_ uiView: StreamingGIFContainerView, coordinator: ()) {
        uiView.stop()
    }
}

final class StreamingGIFContainerView: UIView {
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

    func configure(resourceName: String, resourceExtension: String) {
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

enum OnboardingMascotAsset {
    static var resourceName: String {
        let isTiimo = AlarmThemeStyle.persisted.usesTiimoLayoutBranch
        return isTiimo ? "bluealarm_whitebg" : "bluealarm_blackbg"
    }
}
