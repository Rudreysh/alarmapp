import SwiftUI
import ImageIO

struct OnboardingNameWelcomeView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onNext: () -> Void

    private var isTiimoTheme: Bool {
        SettingsStore.shared.alarmThemeStyle == .tiimo
    }

    var body: some View {
        GeometryReader { proxy in
            let gifSize: CGFloat = isTiimoTheme ? 190 : 200
            let contentWidth = min(proxy.size.width, 460)
            let contentLeading = (proxy.size.width - contentWidth) / 2
            // Keep mascot centered on welcome screen.
            let startX = proxy.size.width * 0.5
            let startY = proxy.size.height * 0.50

            ZStack {
                Colors.bgPrimary.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer().frame(height: 110)

                    Text("Welcome, \(viewModel.displayFirstName)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(Colors.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.l)

                    Text("Let's make your mornings feel better.")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 10)
                        .padding(.horizontal, Spacing.l)

                    Spacer()
                }
                .onboardingContentFrame()

                WelcomeGIFIcon(resourceName: "purple-bg-alarm", resourceExtension: "gif")
                    .frame(width: gifSize, height: gifSize)
                    .position(x: startX, y: startY)
            }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: "Continue", style: .blueGlass) {
                    onNext()
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, Spacing.m)
            }
        }
    }
}

private struct WelcomeGIFIcon: UIViewRepresentable {
    let resourceName: String
    let resourceExtension: String

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        loadGIF(into: imageView)
        return imageView
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        if !uiView.isAnimating {
            loadGIF(into: uiView)
        }
    }

    private func loadGIF(into imageView: UIImageView) {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: resourceExtension),
              let data = try? Data(contentsOf: url),
              let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return
        }

        let frameCount = CGImageSourceGetCount(source)
        guard frameCount > 0 else { return }

        var frames: [UIImage] = []
        var duration: Double = 0
        for index in 0..<frameCount {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            frames.append(UIImage(cgImage: cgImage))
            duration += max(0.02, frameDuration(source: source, index: index))
        }

        guard !frames.isEmpty else { return }
        imageView.stopAnimating()
        imageView.animationImages = frames
        imageView.animationDuration = max(0.1, duration)
        imageView.animationRepeatCount = 0
        imageView.image = frames.first
        imageView.startAnimating()
    }

    private func frameDuration(source: CGImageSource, index: Int) -> Double {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
              let gifProperties = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any] else {
            return 0.1
        }
        let unclamped = gifProperties[kCGImagePropertyGIFUnclampedDelayTime] as? Double
        let clamped = gifProperties[kCGImagePropertyGIFDelayTime] as? Double
        return unclamped ?? clamped ?? 0.1
    }
}
