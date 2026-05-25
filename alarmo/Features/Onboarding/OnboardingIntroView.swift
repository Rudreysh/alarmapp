import SwiftUI
import UIKit
import ImageIO

struct OnboardingIntroView: View {
    let onNext: () -> Void
    var onSkip: (() -> Void)? = nil
    
    @State private var currentPage = 0
    @State private var gifRenderNonce = 0
    @State private var pageOneRevealIndex = 0
    private let totalPages = 3

    
    private var isTiimoTheme: Bool {
        UserDefaults.standard.string(forKey: "settings.alarmThemeStyleRaw") == AlarmThemeStyle.tiimo.rawValue
    }
var body: some View {
        ZStack {
            if currentPage == 0 {
                firstPageBackground
                    .ignoresSafeArea()
            } else {
                Colors.bgPrimary
                    .ignoresSafeArea()
            }
            
            if currentPage != 0 {
                GeometryReader { proxy in
                    let size = proxy.size
                    Circle()
                        .fill(backgroundColors.0.opacity(0.15))
                        .frame(width: 300, height: 300)
                        .blur(radius: 60)
                        .offset(x: size.width - 200, y: -50)
                    
                    Circle()
                        .fill(backgroundColors.1.opacity(0.15))
                        .frame(width: 250, height: 250)
                        .blur(radius: 60)
                        .offset(x: -100, y: size.height * 0.5)
                }
                .animation(.easeInOut(duration: 0.5), value: currentPage)
                .ignoresSafeArea()
            }

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
                
                TabView(selection: $currentPage) {
                    pageIntro.tag(0)
                    pageOne.tag(1)
                    pageTwo.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                // Only animate the transition within the TabView layout
                .animation(.easeInOut, value: currentPage)

                Spacer()
                
                PageDots(count: totalPages, activeIndex: currentPage)
                    .padding(.bottom, Spacing.m)
            }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: currentPage == totalPages - 1 ? "Get Started" : "Continue", style: .blueGlass) {
                    if currentPage < totalPages - 1 {
                        withAnimation {
                            currentPage += 1
                        }
                    } else {
                        onNext()
                    }
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, 48) // Elevated like the other screens
                // Also let the button title animate
                .animation(.easeInOut, value: currentPage)
            }
        }
        .onChange(of: currentPage) { _, newPage in
            // TabView may recycle/detach the first page view and leave GIF playback stopped.
            // Force a remount whenever user comes back to page 0 so animation always restarts.
            if newPage == 0 {
                gifRenderNonce += 1
            }
            if newPage == 1 {
                pageOneRevealIndex = 0
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { pageOneRevealIndex = 1 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.90) { pageOneRevealIndex = 2 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.45) { pageOneRevealIndex = 3 }
            }
        }
    }

    private var firstPageBackground: some View {
        Colors.bgPrimary
    }
    
    // Dynamic background colors
    private var backgroundColors: (Color, Color) {
        switch currentPage {
        case 0: return (Colors.accentTeal, Colors.accentBlue)
        case 1: return (Colors.accentBlue, Color.purple)
        default: return (Colors.accentTeal, Colors.accentBlue)
        }
    }
    
    // MARK: - Pages

    private var pageIntro: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 32)

            Text("Hey! I'm your alarm.")
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundColor(Colors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, 20)

            HStack {
                Spacer()
                if isTiimoTheme {
                    AnimatedGIFView(resourceName: "purple-bg-alarm", resourceExtension: "gif")
                        .frame(width: 253, height: 253)
                        .id("intro-gif-\(gifRenderNonce)")
                } else {
                    Image("alarm-blue")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 253, height: 253)
                }
                Spacer()
            }
            .padding(.bottom, 24)

            Text("(The one you keep snoozing at 2am)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Colors.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.l)
                .padding(.top, 4)

            Spacer()
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

                VStack(spacing: Spacing.m) {
                    bentoCard(icon: "alarm.fill", color: Colors.accentTeal, title: "Smart Alarms", subtitle: "Wake up reliably with alarm missions and louder fallback options.", height: 122)
                        .opacity(pageOneRevealIndex >= 1 ? 1 : 0)
                        .offset(y: pageOneRevealIndex >= 1 ? 0 : 14)
                        .animation(.easeOut(duration: 0.65), value: pageOneRevealIndex)

                    bentoCard(icon: "timer", color: Color.orange, title: "Pomodoro", subtitle: "Stay in deep focus.", height: 122)
                        .opacity(pageOneRevealIndex >= 2 ? 1 : 0)
                        .offset(y: pageOneRevealIndex >= 2 ? 0 : 14)
                        .animation(.easeOut(duration: 0.65), value: pageOneRevealIndex)

                    bentoCard(icon: "chart.xyaxis.line", color: Colors.accentBlue, title: "Progress Reports", subtitle: "Track your daily and weekly consistency at a glance.", height: 122)
                        .opacity(pageOneRevealIndex >= 3 ? 1 : 0)
                        .offset(y: pageOneRevealIndex >= 3 ? 0 : 14)
                        .animation(.easeOut(duration: 0.65), value: pageOneRevealIndex)
                }
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.l)
                .padding(.bottom, Spacing.xl)
            }
        }
        .onAppear {
            if currentPage == 1 && pageOneRevealIndex == 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { pageOneRevealIndex = 1 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.90) { pageOneRevealIndex = 2 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.45) { pageOneRevealIndex = 3 }
            }
        }
    }
    
    private var pageTwo: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                header(title: "Deep Work, Simplified.", subtitle: "Stay focused with app blocking and coordinate better with time overlap.")

                VStack(spacing: Spacing.m) {
                    bentoCard(icon: "shield.lefthalf.filled", color: Color.orange, title: "App Blocking", subtitle: "Block distracting apps during focus sessions and alarm missions.", height: 138)
                }
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
    
    // Bento Card Builder
    private func bentoCard(icon: String, color: Color, title: String, subtitle: String, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(color)
            }
            
            Spacer()
            
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(Colors.textPrimary)
                .padding(.bottom, 2)
                .lineLimit(2)
                .minimumScaleFactor(0.9)
            
            Text(subtitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Colors.textSecondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.l) // robust padding
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: height)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Colors.cardSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Colors.cardStroke, lineWidth: 1)
        )
        .appShadow(Shadows.card)
    }
}

private struct AnimatedGIFView: UIViewRepresentable {
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
