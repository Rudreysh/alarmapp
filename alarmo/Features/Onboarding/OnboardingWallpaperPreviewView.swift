import SwiftUI
import Combine
import UIKit

struct OnboardingQuoteCategorySelectionView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onNext: () -> Void
    @State private var previewQuoteIndex = 0
    private let previewTimer = Timer.publish(every: 8, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                Text("Choose\nmotivation quote")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.top, Spacing.xs)
                    .padding(.bottom, Spacing.xs)

                ProgressHeader(step: 3, total: AppConstants.onboardingTotalSteps)
                    .padding(.horizontal, Spacing.l)
                    .padding(.bottom, Spacing.s)

                Toggle(isOn: Binding(
                    get: { viewModel.state.dailyMotivationEnabled },
                    set: { viewModel.setDailyMotivation($0) }
                )) {
                    Text("Motivation Quotes")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Colors.textPrimary)
                }
                .toggleStyle(SwitchToggleStyle(tint: Colors.accentTeal))
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, Spacing.s)

                ZStack {
                    LinearGradient(
                        colors: [Colors.cardSurface, Colors.bgSecondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                .overlay {
                    if viewModel.state.dailyMotivationEnabled {
                        let quotes = MotivationQuotes.all
                        if !quotes.isEmpty {
                            let quote = quotes[previewQuoteIndex % quotes.count]
                            VStack(spacing: 8) {
                                Text(quote.text)
                                    .font(.system(size: 24, weight: .semibold, design: .serif))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(4)
                                    .minimumScaleFactor(0.75)
                                Text("- \(quote.author)")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.9))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, Spacing.l)
                            .transition(.opacity)
                        }
                    } else {
                        Text("Turn on Motivation Quotes to preview your daily quote.")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Spacing.l)
                    }
                }
                .onReceive(previewTimer) { _ in
                    guard viewModel.state.dailyMotivationEnabled else { return }
                    withAnimation(.easeInOut(duration: 0.8)) {
                        previewQuoteIndex += 1
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: Radii.card))
                .overlay(
                    RoundedRectangle(cornerRadius: Radii.card)
                        .stroke(Colors.cardStroke, lineWidth: 1)
                )
                .frame(height: 380)
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, 120)
            }
            .overlay(alignment: .bottom) {
                PrimaryButton(title: "Next", style: .blueGlass) {
                    onNext()
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, Spacing.l)
            }
        }
    }

}

struct OnboardingWallpaperPreviewView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onBack: () -> Void
    let onSelect: () -> Void
    
    @State private var quoteIndex = 0
    private let quoteTimer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            if let image = viewModel.state.selectedWallpaper?.image() {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
            }

            VStack {
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Colors.textPrimary)
                            .padding(Spacing.s)
                            .background(Colors.bgSecondary.opacity(0.6))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.l)

                Text(currentDateString)
                    .bodyText()
                    .foregroundColor(Colors.textPrimary)
                    .padding(.top, Spacing.s)

                Text(viewModel.selectedTimeString)
                    .font(.system(size: 64, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                    .padding(.top, Spacing.m)
                
                if viewModel.state.dailyMotivationEnabled {
                    let quotes = MotivationQuotes.filteredQuotes(for: viewModel.state.selectedQuoteCategoryIDs)
                    if !quotes.isEmpty {
                        let quote = quotes[quoteIndex % quotes.count]
                        VStack(spacing: 8) {
                            AdaptiveQuoteText(
                                quote: quote.text,
                                maxWidth: max(UIScreen.main.bounds.width - 56, 220),
                                maxLines: 5,
                                maxFontSize: 24,
                                minFontSize: 11,
                                weight: .bold
                            )
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.8), radius: 4, x: 0, y: 2)
                                .id("text-\(quote.id)")
                                .transition(.opacity.combined(with: .scale(scale: 0.98)))

                            Text("- \(quote.author)")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                                .shadow(color: .black.opacity(0.5), radius: 2)
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                                .id("author-\(quote.id)")
                                .transition(.opacity)
                        }
                        .padding(.horizontal, 32)
                        .padding(.top, 40)
                        .onReceive(quoteTimer) { _ in
                            withAnimation(.easeInOut(duration: 1.0)) {
                                quoteIndex += 1
                            }
                        }
                    }
                }

                Spacer()

                PrimaryButton(title: "Continue", style: .blueGlass) {
                    onSelect()
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, Spacing.m)
            }
        }
    }

    private var currentDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE dd. MMM"
        return formatter.string(from: Date())
    }
}
