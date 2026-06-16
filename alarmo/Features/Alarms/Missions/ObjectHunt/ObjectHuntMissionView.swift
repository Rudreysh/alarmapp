import SwiftUI
import AVFoundation

struct ObjectHuntMissionView: View {
    @Environment(\.dismiss) private var dismiss
    var onComplete: (() -> Void)?

    struct TargetObject: Identifiable {
        let id = UUID()
        let emoji: String
        let name: String
        let keywords: [String]
    }

    private let objects: [TargetObject] = [
        TargetObject(emoji: "🧴", name: "Bottle", keywords: ["bottle", "water bottle", "flask", "container"]),
        TargetObject(emoji: "🍴", name: "Spoon", keywords: ["spoon", "utensil", "cutlery"]),
        TargetObject(emoji: "📚", name: "Book", keywords: ["book", "notebook", "textbook", "binder"]),
        TargetObject(emoji: "🎧", name: "Headphones", keywords: ["headphone", "headset", "earphone"]),
        TargetObject(emoji: "🪥", name: "Toothbrush", keywords: ["toothbrush", "brush"]),
        TargetObject(emoji: "👟", name: "Shoe", keywords: ["shoe", "sneaker", "footwear"]),
        TargetObject(emoji: "🧻", name: "Tissue", keywords: ["tissue", "paper towel", "toilet tissue", "napkin"]),
        TargetObject(emoji: "🧼", name: "Soap", keywords: ["soap", "detergent"]),
        TargetObject(emoji: "⌚️", name: "Watch", keywords: ["watch", "clock", "wristwatch"]),
        TargetObject(emoji: "🔑", name: "Keys", keywords: ["key", "keys", "keychain"])
    ]

    @State private var selectedIndex: Int = 0
    @State private var spinning = false
    @State private var spinTask: Task<Void, Never>?

    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var permissionDenied = false

    @State private var feedbackText: String?
    @State private var feedbackColor: Color = Colors.textSecondary
    @State private var isEvaluating = false

    @State private var didComplete = false

    private var currentObject: TargetObject {
        objects[selectedIndex]
    }

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()

            VStack(spacing: 20) {
                header

                Text("Find this object")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Colors.textSecondary)

                roulette
                    .padding(.horizontal, 16)

                VStack(spacing: 8) {
                    Text(currentObject.emoji)
                        .font(.system(size: 56))
                    Text(currentObject.name)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                }
                .padding(.top, 6)

                if let feedbackText {
                    Text(feedbackText)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(feedbackColor)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                if isEvaluating {
                    ProgressView("Checking similarity...")
                        .tint(Colors.accentTeal)
                        .foregroundColor(Colors.textPrimary)
                }

                HStack(spacing: 12) {
                    Button(action: startSpin) {
                        Label("Respin", systemImage: "arrow.triangle.2.circlepath")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Colors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Colors.cardSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(Colors.cardStroke, lineWidth: 1)
                            )
                            .cornerRadius(18)
                    }
                    .disabled(spinning || isEvaluating)

                    Button(action: capturePhotoTapped) {
                        Label("Capture", systemImage: "camera.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Colors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Colors.accentTeal,
                                        Colors.accentBlue
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(18)
                    }
                    .disabled(spinning || isEvaluating)
                }
                .padding(.horizontal, 20)

                Spacer()

                Text("Tip: similar category also works. If unavailable, use respin.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Colors.textSecondary)
                    .padding(.bottom, 12)
            }
        }
        .onAppear {
            startSpin()
        }
        .onDisappear {
            spinTask?.cancel()
        }
        .fullScreenCover(isPresented: $showCamera) {
            ImagePicker(sourceType: .camera) { image in
                evaluate(image: image)
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showLibrary) {
            ImagePicker(sourceType: .photoLibrary) { image in
                evaluate(image: image)
            }
            .ignoresSafeArea()
        }
        .alert("Camera permission needed", isPresented: $permissionDenied) {
            Button("Cancel", role: .cancel) {}
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text("Allow camera access to capture object photos.")
        }
    }

    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(Colors.cardSurface)
                    .overlay(
                        Circle().stroke(Colors.cardStroke, lineWidth: 1)
                    )
                    .clipShape(Circle())
            }

            Spacer()

            Text("Object Hunt")
                .font(.system(size: 19, weight: .bold))
                .foregroundColor(Colors.textPrimary)

            Spacer()

            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
    }

    private var roulette: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28)
                .fill(Colors.cardSurface)
                .overlay(RoundedRectangle(cornerRadius: 28).stroke(Colors.cardStroke, lineWidth: 1))

            HStack(spacing: 12) {
                ForEach(-2...2, id: \.self) { offset in
                    let item = objects[wrappedIndex(selectedIndex + offset)]
                    let isCenter = offset == 0
                    VStack(spacing: 8) {
                        Text(item.emoji)
                            .font(.system(size: isCenter ? 42 : 30))
                        Text(item.name)
                            .font(.system(size: isCenter ? 16 : 12, weight: .bold))
                            .foregroundColor(isCenter ? Colors.textPrimary : Colors.textSecondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .opacity(isCenter ? 1 : 0.4)
                    .scaleEffect(isCenter ? 1 : 0.88)
                }
            }
            .padding(.horizontal, 8)
            .animation(.easeInOut(duration: 0.2), value: selectedIndex)
        }
        .frame(height: 168)
    }

    private func wrappedIndex(_ value: Int) -> Int {
        let count = objects.count
        return (value % count + count) % count
    }

    private func startSpin() {
        guard !spinning else { return }
        spinTask?.cancel()

        spinning = true
        feedbackText = nil

        spinTask = Task {
            let totalTicks = 28
            for tick in 0..<totalTicks {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    selectedIndex = wrappedIndex(selectedIndex + 1)
                }
                let delay = UInt64((0.06 + Double(tick) * 0.006) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: delay)
            }

            await MainActor.run {
                selectedIndex = Int.random(in: 0..<objects.count)
                spinning = false
            }
        }
    }

    private func capturePhotoTapped() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showLibrary = true
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted { showCamera = true } else { permissionDenied = true }
                }
            }
        case .restricted, .denied:
            permissionDenied = true
        @unknown default:
            permissionDenied = true
        }
    }

    private func evaluate(image: UIImage?) {
        guard let image else { return }

        isEvaluating = true
        feedbackText = nil

        Task {
            let labels = await ObjectHuntMatcher.classify(image: image)
            let matched = ObjectHuntMatcher.matches(targetKeywords: currentObject.keywords, labels: labels)

            await MainActor.run {
                isEvaluating = false
                if matched {
                    feedbackColor = Colors.accentGreen
                    feedbackText = "Matched \(currentObject.name). Mission complete."
                    UINotificationFeedbackGenerator().notificationOccurred(.success)

                    guard !didComplete else { return }
                    didComplete = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                        onComplete?()
                        dismiss()
                    }
                } else {
                    feedbackColor = Colors.accentRed
                    feedbackText = "No close match found. Try another angle or respin."
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }
    }
}
