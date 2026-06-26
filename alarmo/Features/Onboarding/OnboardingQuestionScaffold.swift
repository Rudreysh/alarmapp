import SwiftUI
import ImageIO

struct OnboardingQuestionScaffold: View {
    let title: String
    var subtitle: String? = nil
    let options: [QuestionOption]
    @Binding var selectedOptionID: String?
    let selectedColor: Color
    let questionIndex: Int
    let questionTotal: Int
    let onNext: () -> Void
    @Environment(\.onboardingQuestionMascotHidden) private var isQuestionMascotHidden
    @State private var appeared = false

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                QuestionnaireHeaderRow(
                    progress: progressFraction,
                    tint: selectedColor,
                    track: selectedColor.opacity(0.20),
                    isMascotHidden: isQuestionMascotHidden
                )
                .padding(.horizontal, Spacing.l)
                .padding(.top, 20)
                .padding(.bottom, 12)

                Text(title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, Spacing.l)
                    .padding(.bottom, subtitle == nil ? 18 : 6)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.l)
                        .padding(.bottom, 16)
                }

                VStack(spacing: 10) {
                    ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
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
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 14)
                        .animation(
                            .spring(response: 0.45, dampingFraction: 0.8)
                                .delay(0.05 + Double(index) * 0.06),
                            value: appeared
                        )
                    }
                }
                .padding(.horizontal, Spacing.l)

                Spacer()
            }
            .onboardingContentFrame()
            .onAppear { appeared = true }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: "Continue", style: .blueGlass, action: onNext)
                    .padding(.horizontal, Spacing.l)
                    .padding(.bottom, Spacing.m)
                    .disabled(selectedOptionID == nil)
                    .opacity(selectedOptionID == nil ? 0.55 : 1.0)
            }
        }
    }

    private func borderColor(for optionID: String) -> Color {
        optionID == selectedOptionID ? selectedColor : Color.black.opacity(0.10)
    }

    private var progressFraction: CGFloat {
        guard questionTotal > 0 else { return 0 }
        return min(max(CGFloat(questionIndex) / CGFloat(questionTotal), 0), 1)
    }
}

struct QuestionOption: Identifiable {
    let id: String
    let text: String
    var emoji: String? = nil
}

private struct QuestionnaireHeaderRow: View {
    let progress: CGFloat
    let tint: Color
    let track: Color
    let isMascotHidden: Bool

    private var isTiimo: Bool {
        AlarmThemeStyle.persisted.usesTiimoLayoutBranch
    }

    private var glowColor: Color {
        isTiimo ? Color(hex: "F5C87A").opacity(0.38) : Color(hex: "9B59F5").opacity(0.35)
    }

    private var ringColor: Color {
        isTiimo ? Color(hex: "E8D7C0").opacity(0.4) : Color(hex: "FFB84A").opacity(0.18)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(track)
                    Capsule()
                        .fill(tint)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 10)

            ZStack {
                if !isMascotHidden {
                    Circle()
                        .fill(glowColor)
                        .frame(width: 58, height: 58)
                        .blur(radius: 7)
                        .offset(y: 3)
                }

                QuestionHeaderGIFIcon(resourceName: OnboardingMascotAsset.resourceName, resourceExtension: "gif", size: 64)
                    .frame(width: 64, height: 64)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(ringColor, lineWidth: 1.0)
                    )
            }
            .frame(width: 64, height: 64)
            .fixedSize()
            .opacity(isMascotHidden ? 0 : 1)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: OnboardingQuestionMascotFramePreferenceKey.self,
                        value: geo.frame(in: .named(OnboardingMascotFlightCoordinateSpace.name))
                    )
                }
            )
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
