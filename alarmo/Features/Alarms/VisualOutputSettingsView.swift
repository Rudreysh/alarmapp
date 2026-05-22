import SwiftUI
import Photos
import UIKit

struct VisualOutputSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var wallpaperId: String
    @Binding var dailyMotivationEnabled: Bool
    @Binding var settings: AlarmVisualOutputSettings

    @State private var showWallpaperPicker = false
    @State private var infoMessage: String?
    @State private var infoTitle: String = "Notice"

    var body: some View {
        NavigationStack {
            ZStack {
                Colors.bgPrimary.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        sectionTitle("Selected Wallpaper")
                        wallpaperPreviewCard

                        sectionTitle("Wallpaper")
                        GroupedSettingsCard {
                            MenuRow(
                                icon: "photo.fill",
                                title: "Wallpaper",
                                value: "Change",
                                thumbnail: resolvedWallpaperImage
                            ) {
                                showWallpaperPicker = true
                            }

                            Divider().padding(.leading, 16).opacity(0.3)

                            Toggle("Use wallpaper as iPhone wallpaper", isOn: Binding(
                                get: { isWallpaperOnPhone },
                                set: { setPhoneSurface(wallpaper: $0, quotes: isQuotesOnPhone) }
                            ))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)

                            Divider().padding(.leading, 16).opacity(0.3)

                            Toggle("Use wallpaper as screen saver", isOn: Binding(
                                get: { isWallpaperOnSaver },
                                set: { setSaverSurface(wallpaper: $0, quotes: isQuotesOnSaver) }
                            ))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }

                        sectionTitle("Quotes")
                        GroupedSettingsCard {
                            Toggle("Display quotes on wallpaper", isOn: Binding(
                                get: { isQuotesOnPhone },
                                set: { setPhoneSurface(wallpaper: isWallpaperOnPhone, quotes: $0) }
                            ))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)

                            Divider().padding(.leading, 16).opacity(0.3)

                            Toggle("Display quotes on screen saver", isOn: Binding(
                                get: { isQuotesOnSaver },
                                set: { setSaverSurface(wallpaper: isWallpaperOnSaver, quotes: $0) }
                            ))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }

                        sectionTitle("Apply on iPhone")
                        GroupedSettingsCard {
                            applyRow(
                                icon: "iphone",
                                title: "Apply iPhone wallpaper"
                            ) {
                                exportAndSaveWallpaper(for: .phone)
                            }

                            Divider().padding(.leading, 16).opacity(0.3)

                            applyRow(
                                icon: "lock.display",
                                title: "Apply screen saver"
                            ) {
                                exportAndSaveWallpaper(for: .screenSaver)
                            }
                        }

                        Text("iOS does not allow any app to set wallpaper automatically. Awayk requests Photos access, saves the prepared image, and you can set it from Photos.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Colors.textSecondary)
                            .padding(.horizontal, 6)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Wallpaper & Quotes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(Colors.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        syncLegacyFields()
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Colors.accentTeal)
                }
            }
            .sheet(isPresented: $showWallpaperPicker) {
                WallpaperPickerView(selectedId: $wallpaperId)
            }
            .alert(infoTitle, isPresented: Binding(
                get: { infoMessage != nil },
                set: { isPresented in
                    if !isPresented { infoMessage = nil }
                }
            )) {
                Button("OK", role: .cancel) { infoMessage = nil }
            } message: {
                Text(infoMessage ?? "")
            }
            .onAppear {
                syncLegacyFields()
            }
        }
    }

    private var isWallpaperOnPhone: Bool {
        (settings.lockScreen.enabled && modeIncludesWallpaper(settings.lockScreen.mode))
            || (settings.homeScreen.enabled && modeIncludesWallpaper(settings.homeScreen.mode))
    }

    private var isQuotesOnPhone: Bool {
        (settings.lockScreen.enabled && modeIncludesQuotes(settings.lockScreen.mode))
            || (settings.homeScreen.enabled && modeIncludesQuotes(settings.homeScreen.mode))
    }

    private var isWallpaperOnSaver: Bool {
        settings.standBy.enabled && modeIncludesWallpaper(settings.standBy.mode)
    }

    private var isQuotesOnSaver: Bool {
        settings.standBy.enabled && modeIncludesQuotes(settings.standBy.mode)
    }

    private enum ExportTarget {
        case phone
        case screenSaver
    }

    private func setPhoneSurface(wallpaper: Bool, quotes: Bool) {
        let mode = combinedMode(wallpaper: wallpaper, quotes: quotes)
        let enabled = wallpaper || quotes
        settings.lockScreen.enabled = enabled
        settings.homeScreen.enabled = enabled
        settings.lockScreen.mode = mode
        settings.homeScreen.mode = mode
        settings.lockScreen.isApplied = !enabled
        settings.homeScreen.isApplied = !enabled
        syncLegacyFields()
    }

    private func setSaverSurface(wallpaper: Bool, quotes: Bool) {
        settings.standBy.enabled = wallpaper || quotes
        settings.standBy.mode = combinedMode(wallpaper: wallpaper, quotes: quotes)
        settings.standBy.isApplied = !settings.standBy.enabled
        syncLegacyFields()
    }

    private func combinedMode(wallpaper: Bool, quotes: Bool) -> VisualSurfaceMode {
        if wallpaper && quotes { return .both }
        if quotes { return .quotes }
        return .wallpaper
    }

    private func modeIncludesQuotes(_ mode: VisualSurfaceMode) -> Bool {
        mode == .quotes || mode == .both
    }

    private func modeIncludesWallpaper(_ mode: VisualSurfaceMode) -> Bool {
        mode == .wallpaper || mode == .both
    }

    private func syncLegacyFields() {
        dailyMotivationEnabled = isQuotesOnPhone || isQuotesOnSaver
        settings.alarmScreen.enabled = true
        settings.alarmScreen.mode = dailyMotivationEnabled ? .both : .wallpaper
        settings.alarmScreen.isApplied = true
        settings.contentSource = dailyMotivationEnabled ? .wallpaperAndQuotes : .wallpaper
        settings.wallpaperSource = .alarmWallpaper
    }

    private func exportAndSaveWallpaper(for target: ExportTarget) {
        let includeQuotes = target == .phone ? isQuotesOnPhone : isQuotesOnSaver
        guard let image = renderedImage(includeQuotes: includeQuotes) else {
            infoTitle = "Export Failed"
            infoMessage = "Couldn't prepare image from selected wallpaper."
            return
        }

        requestPhotoAddAccess { granted in
            guard granted else {
                DispatchQueue.main.async {
                    infoTitle = "Photos Permission Needed"
                    infoMessage = "Allow Photos access to export wallpaper. Then set it from Photos > Share > Use as Wallpaper."
                }
                return
            }

            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, error in
                DispatchQueue.main.async {
                    if success {
                        infoTitle = "Saved to Photos"
                        infoMessage = "Open Photos, choose the image, tap Share, then Use as Wallpaper."
                    } else {
                        infoTitle = "Save Failed"
                        infoMessage = error?.localizedDescription ?? "Could not save image to Photos."
                    }
                }
            }
        }
    }

    private func requestPhotoAddAccess(completion: @escaping (Bool) -> Void) {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .authorized, .limited:
            completion(true)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                completion(newStatus == .authorized || newStatus == .limited)
            }
        default:
            completion(false)
        }
    }

    private func renderedImage(includeQuotes: Bool) -> UIImage? {
        let baseImage = WallpaperImageResolver.resolveImage(for: wallpaperId)
        let size = CGSize(width: 1179, height: 2556) // iPhone portrait wallpaper ratio
        let renderer = UIGraphicsImageRenderer(size: size)

        let quote = selectedQuote()
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)

            if let baseImage {
                baseImage.draw(in: rect)
            } else {
                UIColor.black.setFill()
                context.fill(rect)
            }

            if includeQuotes, let quote {
                let gradientHeight = size.height * 0.42
                let gradientRect = CGRect(x: 0, y: size.height - gradientHeight, width: size.width, height: gradientHeight)
                let colors = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.72).cgColor]
                let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])
                if let gradient {
                    context.cgContext.drawLinearGradient(
                        gradient,
                        start: CGPoint(x: 0, y: gradientRect.minY),
                        end: CGPoint(x: 0, y: gradientRect.maxY),
                        options: []
                    )
                }

                let paragraph = NSMutableParagraphStyle()
                paragraph.alignment = .left
                paragraph.lineBreakMode = .byWordWrapping

                let quoteAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 64, weight: .bold),
                    .foregroundColor: UIColor.white,
                    .paragraphStyle: paragraph
                ]
                let authorAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 42, weight: .medium),
                    .foregroundColor: UIColor.white.withAlphaComponent(0.9),
                    .paragraphStyle: paragraph
                ]

                let padding: CGFloat = 88
                let quoteBounds = CGRect(
                    x: padding,
                    y: size.height - 820,
                    width: size.width - (padding * 2),
                    height: 560
                )
                let authorBounds = CGRect(
                    x: padding,
                    y: size.height - 240,
                    width: size.width - (padding * 2),
                    height: 120
                )

                NSString(string: "“\(quote.text)”").draw(in: quoteBounds, withAttributes: quoteAttrs)
                NSString(string: "- \(quote.author)").draw(in: authorBounds, withAttributes: authorAttrs)
            }
        }
    }

    private func selectedQuote() -> MotivationQuote? {
        let quotes = MotivationQuotes.dailyQuotes()
        guard !quotes.isEmpty else { return nil }
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return quotes[(dayOfYear - 1) % quotes.count]
    }

    private var resolvedWallpaperImage: Image? {
        guard let uiImage = WallpaperImageResolver.resolveImage(for: wallpaperId) else {
            return nil
        }
        return Image(uiImage: uiImage)
    }

    private var wallpaperPreviewCard: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let preview = resolvedWallpaperImage {
                    preview
                        .resizable()
                        .scaledToFill()
                } else {
                    LinearGradient(
                        colors: [Colors.cardSurface, Colors.cardSurface.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .overlay {
                        Image(systemName: "photo")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundColor(Colors.textSecondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 180)
            .clipped()

            LinearGradient(
                colors: [.clear, .black.opacity(0.55)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 4) {
                Text("Current selection")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                Text("Used for alarm, wallpaper, and screen saver")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
        .background(Colors.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            showWallpaperPicker = true
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(Colors.textSecondary)
            .padding(.leading, 4)
    }

    private func applyRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(Colors.textPrimary)
                    .frame(width: 24)

                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Colors.textPrimary)

                Spacer()

                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Colors.accentTeal)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
