import SwiftUI
import UIKit
import ImageIO
import Combine

struct OnboardingIntroView: View {
    let onNext: () -> Void
    var onSkip: (() -> Void)? = nil
    
    @State private var currentPage = 0
    @State private var gifRenderNonce = 0
    @State private var pageIntroRevealIndex = 0

    
    private var isTiimoTheme: Bool {
        UserDefaults.standard.string(forKey: "settings.alarmThemeStyleRaw") == AlarmThemeStyle.tiimo.rawValue
    }
var body: some View {
        ZStack {
            Colors.bgPrimary
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with Skip
                HStack {
                    Spacer()
                    if let onSkip = onSkip {
                        Button("Skip") {
                            onSkip()
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isTiimoTheme ? .black : Colors.textSecondary)
                        .padding()
                    }
                }
                
                pageIntro

                Spacer()
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    PrimaryButton(title: "Continue", style: .blueGlass) {
                        onNext()
                    }
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, 48) // Elevated like the other screens
            }
        }
        .onChange(of: currentPage) { _, newPage in
            // TabView may recycle/detach the first page view and leave GIF playback stopped.
            // Force a remount whenever user comes back to page 0 so animation always restarts.
            if newPage == 0 {
                gifRenderNonce += 1
            }
            if newPage == 0 {
                pageIntroRevealIndex = 0
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) { pageIntroRevealIndex = 1 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) { pageIntroRevealIndex = 2 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.62) { pageIntroRevealIndex = 3 }
            }
        }
        .onAppear {
            if isTiimoTheme {
                pageIntroRevealIndex = 0
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) { pageIntroRevealIndex = 1 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) { pageIntroRevealIndex = 2 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.62) { pageIntroRevealIndex = 3 }
            }
        }
    }

    // MARK: - Pages

    private var pageIntro: some View {
        GeometryReader { proxy in
            ZStack {
                VStack(spacing: 0) {
                    Spacer().frame(height: 110)

                    Text("Hey! I'm your alarm.")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundColor(Colors.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.l)
                        .padding(.bottom, 20)
                        .opacity(!isTiimoTheme || pageIntroRevealIndex >= 1 ? 1 : 0)
                        .offset(y: !isTiimoTheme || pageIntroRevealIndex >= 1 ? 0 : 16)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: pageIntroRevealIndex)

                    Text("(The one you keep snoozing at 2am)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Colors.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                        .padding(.horizontal, Spacing.l)
                        .opacity(!isTiimoTheme || pageIntroRevealIndex >= 3 ? 1 : 0)
                        .offset(y: !isTiimoTheme || pageIntroRevealIndex >= 3 ? 0 : 12)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.15), value: pageIntroRevealIndex)

                    Spacer()
                }

                AnimatedGIFView(resourceName: OnboardingMascotAsset.resourceName, resourceExtension: "gif")
                    .frame(width: 252, height: 252)
                    .id("intro-gif-\(gifRenderNonce)")
                    .position(x: proxy.size.width * 0.5, y: proxy.size.height * 0.58)
                    .opacity(!isTiimoTheme || pageIntroRevealIndex >= 2 ? 1 : 0)
                    .offset(y: !isTiimoTheme || pageIntroRevealIndex >= 2 ? 0 : 16)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: pageIntroRevealIndex)
            }
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

    final class ContainerView: UIView {
        let imageView = UIImageView()
    }

    func makeUIView(context: Context) -> ContainerView {
        let container = ContainerView()
        let imageView = container.imageView
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.backgroundColor = .clear
        configureAnimation(on: imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: container.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        container.clipsToBounds = true
        container.backgroundColor = .clear
        return container
    }

    func updateUIView(_ uiView: ContainerView, context: Context) {
        let imageView = uiView.imageView
        if imageView.animationImages == nil || imageView.animationImages?.isEmpty == true {
            configureAnimation(on: imageView)
        } else if !imageView.isAnimating {
            imageView.startAnimating()
        }
    }

    private func configureAnimation(on imageView: UIImageView) {
        guard let (frames, duration) = loadFramesAndDuration() else { return }
        imageView.stopAnimating()
        imageView.animationImages = frames
        imageView.animationDuration = max(duration, 0.1)
        imageView.animationRepeatCount = 0 // infinite loop
        imageView.image = frames.first
        imageView.startAnimating()
    }

    private func loadFramesAndDuration() -> ([UIImage], Double)? {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: resourceExtension),
              let data = try? Data(contentsOf: url),
              let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }

        let frameCount = CGImageSourceGetCount(source)
        guard frameCount > 0 else { return nil }

        var frames: [UIImage] = []
        var totalDuration: Double = 0

        for index in 0..<frameCount {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            let duration = frameDuration(from: source, at: index)
            totalDuration += duration
            frames.append(UIImage(cgImage: cgImage))
        }

        guard !frames.isEmpty else { return nil }
        return (frames, totalDuration)
    }

    private func frameDuration(from source: CGImageSource, at index: Int) -> Double {
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
        let isTiimo = UserDefaults.standard.string(forKey: "settings.alarmThemeStyleRaw") == AlarmThemeStyle.tiimo.rawValue
        return isTiimo ? "bluealarm_whitebg" : "bluealarm_blackbg"
    }
}
