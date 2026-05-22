import SwiftUI

struct TimerPlaceholderView: View {
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()

            VStack {
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Colors.textPrimary)
                            .frame(width: 44, height: 44)
                    }
                    Spacer()
                }
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.l)

                Spacer()
            }
        }
    }
}
