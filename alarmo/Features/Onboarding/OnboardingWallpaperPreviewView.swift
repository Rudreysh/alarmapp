import SwiftUI
import Combine
import UIKit

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
                Colors.bgPrimary.ignoresSafeArea()
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
                    let quotes = MotivationQuotes.dailyQuotes()
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

                PrimaryButton(title: "Select", style: .blueGlass) {
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
