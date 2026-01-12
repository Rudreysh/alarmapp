import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel

    init(viewModel: HomeViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Colors.bgSecondary, Colors.bgPrimary], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ZStack {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    HStack {
                        Spacer()
                        Button(action: {}) {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(Colors.textSecondary)
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel(Text("More options"))
                    }
                    .padding(.top, Spacing.s)

                    if viewModel.showProBanner {
                        Button(action: viewModel.tapProBanner) {
                            HStack(spacing: 8) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Colors.accentRed)
                                Text("PRO Free Trial")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Colors.textPrimary)
                            }
                            .padding(.horizontal, Spacing.m)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Colors.accentRed.opacity(0.6), lineWidth: 1)
                            )
                        }
                        .buttonStyle(PressedScaleButtonStyle())
                    }

                    PromoCard(
                        iconSystemName: "moon.zzz.fill",
                        title: "Track your snoring",
                        subtitle: "Half of people snored last night"
                    ) {}

                    Text("No upcoming alarms")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                        .padding(.top, Spacing.s)

                    Spacer()
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, AppConstants.tabBarHeight + Spacing.xl)

                Text("No alarm set")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Colors.textTertiary)
                    .frame(maxHeight: .infinity, alignment: .center)

                VStack {
                    Spacer()
                    Button(action: viewModel.tapRemoveAds) {
                        HStack(spacing: 8) {
                            Image(systemName: "nosign")
                                .foregroundColor(Colors.textSecondary)
                            Text("Remove all ads")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Colors.textSecondary)
                        }
                        .padding(.vertical, 10)
                    }
                    .accessibilityLabel(Text("Remove all ads"))
                    .padding(.bottom, AppConstants.tabBarHeight + Spacing.s)
                }
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {}) {
                        Image(systemName: "plus")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(Colors.textPrimary)
                            .frame(width: 62, height: 62)
                            .background(Colors.accentRed)
                            .clipShape(Circle())
                            .appShadow(Shadows.card)
                    }
                    .accessibilityLabel(Text("Add alarm"))
                    .padding(.trailing, Spacing.l)
                    .padding(.bottom, AppConstants.tabBarHeight + Spacing.l)
                }
            }

            if viewModel.showCelebration {
                CelebrationOverlayView {
                    viewModel.celebrationDidFinish()
                }
            }

            if viewModel.showDiscountPaywall {
                DiscountPaywallView(
                    preferences: viewModel.preferences,
                    onClose: viewModel.dismissPaywall,
                    onApply: viewModel.dismissPaywall
                )
            }
        }
        .onAppear { viewModel.onAppear() }
    }
}
