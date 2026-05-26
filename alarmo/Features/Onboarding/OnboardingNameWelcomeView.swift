import SwiftUI

struct OnboardingNameWelcomeView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    var isMascotHidden = false
    let onNext: () -> Void
    @State private var isMascotFlying = false
    @State private var isAdvancing = false

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
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
                .frame(width: proxy.size.width, height: proxy.size.height)

                AnimatedGIFView(resourceName: OnboardingMascotAsset.resourceName, resourceExtension: "gif")
                    .frame(width: mascotSize, height: mascotSize)
                    .position(mascotPosition(in: proxy))
                    .opacity(isMascotHidden ? 0 : 1)
                    .animation(.easeInOut(duration: 0.55), value: isMascotFlying)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: OnboardingWelcomeMascotFramePreferenceKey.self,
                                value: geo.frame(in: .named(OnboardingMascotFlightCoordinateSpace.name))
                            )
                        }
                    )
                    .zIndex(10)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "Continue", style: .blueGlass) {
                advanceWithAnimation()
            }
            .padding(.horizontal, Spacing.l)
            .padding(.bottom, Spacing.m)
            .disabled(isAdvancing)
            .opacity(isAdvancing ? 0.7 : 1.0)
        }
        .onAppear {
            isAdvancing = false
            isMascotFlying = false
        }
    }

    private var mascotSize: CGFloat {
        isMascotFlying ? 64 : 252
    }

    private func mascotPosition(in proxy: GeometryProxy) -> CGPoint {
        isMascotFlying ? mascotTargetPosition(in: proxy) : mascotStartPosition(in: proxy)
    }

    private func mascotStartPosition(in proxy: GeometryProxy) -> CGPoint {
        CGPoint(x: proxy.size.width * 0.5, y: proxy.size.height * 0.58)
    }

    private func mascotTargetPosition(in proxy: GeometryProxy) -> CGPoint {
        // Matches the questionary header GIF: padding-top 20 + half of 64pt GIF = 52pt from content top.
        // X mirrors the right-aligned 64pt icon with Spacing.l (24pt) right padding.
        CGPoint(x: proxy.size.width - Spacing.l - 32, y: 52)
    }

    private func advanceWithAnimation() {
        guard !isAdvancing else { return }
        isAdvancing = true
        isMascotFlying = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            onNext()
        }
    }
}
