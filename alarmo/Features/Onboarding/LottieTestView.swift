import SwiftUI

#if canImport(DotLottie)
import DotLottie
#endif

struct LottieTestView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.95).ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Lottie Smoke Test")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

#if canImport(DotLottie)
                // Put your downloaded file at: alarmo/Animations/alarm-bell.lottie
                DotLottieAnimation(
                    fileName: "alarm-bell",
                    config: AnimationConfig(autoplay: true, loop: true)
                )
                .frame(width: 220, height: 220)
#else
                Text("DotLottie not linked yet.\nAdd package: https://github.com/LottieFiles/dotlottie-ios")
                    .font(.system(size: 14, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.85))
                    .padding(16)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
#endif
            }
            .padding(24)
        }
    }
}

#Preview {
    LottieTestView()
}
