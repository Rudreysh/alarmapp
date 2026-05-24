import SwiftUI
import UIKit
import ImageIO

struct OnboardingIntroView: View {
    let onNext: () -> Void
    var onSkip: (() -> Void)? = nil
    
    @State private var currentPage = 0
    private let totalPages = 3

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
                        .foregroundColor(Colors.textSecondary)
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
    }

    private var firstPageBackground: some View {
        ZStack {
            Color(hex: "#F6F5F3")

            LinearGradient(
                colors: [
                    Color(hex: "#F6F5F3").opacity(0.0),
                    Color(hex: "#FFD9C7").opacity(0.65)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    Color(hex: "#FFC7AD").opacity(0.40),
                    Color(hex: "#FFC7AD").opacity(0.0)
                ],
                center: .bottom,
                startRadius: 20,
                endRadius: 460
            )
        }
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
                AnimatedGIFView(resourceName: "purple-bg-alarm", resourceExtension: "gif")
                    .frame(width: 220, height: 220)
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
                header(title: "Master your time.", subtitle: "Alarms, habits and focus in one unified workspace.")

                VStack(spacing: Spacing.m) {
                    bentoCard(icon: "alarm.fill", color: Colors.accentTeal, title: "Smart Alarms", subtitle: "Wake up reliably with alarm missions and louder fallback options.", height: 138)

                    bentoCard(icon: "timer", color: Color.orange, title: "Pomodoro", subtitle: "Stay in deep focus.", height: 124)

                    bentoCard(icon: "chart.xyaxis.line", color: Colors.accentBlue, title: "Progress Reports", subtitle: "Track your daily and weekly consistency at a glance.", height: 116)
                }
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.xl)
                .padding(.bottom, Spacing.xxl)
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
        imageView.image = loadAnimatedImage()
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
        if uiView.imageView.image == nil {
            uiView.imageView.image = loadAnimatedImage()
        }
    }

    private func loadAnimatedImage() -> UIImage? {
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
        return UIImage.animatedImage(with: frames, duration: max(totalDuration, 0.1))
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
