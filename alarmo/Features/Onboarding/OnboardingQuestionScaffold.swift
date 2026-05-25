import SwiftUI
import ImageIO

struct OnboardingQuestionScaffold: View {
    let title: String
    let options: [QuestionOption]
    @Binding var selectedOptionID: String
    let selectedColor: Color
    let questionIndex: Int
    let questionTotal: Int
    let onNext: () -> Void

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 16) {
                    QuestionnaireProgressBar(progress: progressFraction, tint: selectedColor)
                        .frame(height: 12)
                    QuestionHeaderGIFIcon(resourceName: "purple-bg-alarm", resourceExtension: "gif", size: 76)
                        .frame(width: 76, height: 76)
                        .fixedSize()
                }
                .padding(.horizontal, Spacing.l)
                .padding(.top, 20)
                .padding(.bottom, 12)

                Text(title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, Spacing.l)
                    .padding(.bottom, 18)

                VStack(spacing: 10) {
                    ForEach(options) { option in
                        Button {
                            selectedOptionID = option.id
                        } label: {
                            HStack(spacing: 14) {
                                if let emoji = option.emoji {
                                    Text(emoji)
                                        .font(.system(size: 22))
                                }
                                Text(option.text)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Colors.textPrimary)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 72)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(option.id == selectedOptionID ? selectedColor.opacity(0.09) : Colors.cardSurface.opacity(0.55))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(borderColor(for: option.id), lineWidth: option.id == selectedOptionID ? 2.0 : 1)
                            )
                            .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Spacing.l)

                Spacer()
            }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: "Continue", style: .alarmDefault, action: onNext)
                    .padding(.horizontal, Spacing.l)
                    .padding(.bottom, Spacing.m)
            }
        }
    }

    private func borderColor(for optionID: String) -> Color {
        optionID == selectedOptionID ? selectedColor : Color.black.opacity(0.10)
    }

    private var progressFraction: CGFloat {
        guard questionTotal > 0 else { return 0 }
        let clamped = min(max(questionIndex, 1), questionTotal)
        return CGFloat(clamped) / CGFloat(questionTotal)
    }
}

struct QuestionOption: Identifiable {
    let id: String
    let text: String
    var emoji: String? = nil
}

private struct QuestionnaireProgressBar: View {
    let progress: CGFloat
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            let width = max(0, proxy.size.width * min(max(progress, 0), 1))
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color.black.opacity(0.10))
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.75))
                    .frame(width: width)
            }
        }
    }
}

private struct QuestionHeaderGIFIcon: UIViewRepresentable {
    let resourceName: String
    let resourceExtension: String
    let size: CGFloat

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        imageView.setContentHuggingPriority(.required, for: .vertical)
        imageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.required, for: .vertical)
        loadGIF(into: imageView)
        return imageView
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIImageView, context: Context) -> CGSize? {
        CGSize(width: size, height: size)
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        uiView.bounds.size = CGSize(width: size, height: size)
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
