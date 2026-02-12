import SwiftUI

struct OnboardingWallpaperPreviewView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onBack: () -> Void
    let onSelect: () -> Void

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
