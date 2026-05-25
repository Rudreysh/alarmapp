import SwiftUI

struct OnboardingNameView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onNext: () -> Void
    @State private var firstName: String = ""
    @FocusState private var isNameFocused: Bool

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Text("What’s your name?")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(Colors.textPrimary)
                    .padding(.top, 120)

                TextField("Julia", text: $firstName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .font(.system(size: 33, weight: .regular))
                    .foregroundColor(Colors.textPrimary)
                    .padding(.top, 72)
                    .focused($isNameFocused)

                Rectangle()
                    .fill(Colors.textSecondary.opacity(0.15))
                    .frame(height: 1)
                    .padding(.top, 10)

                Spacer()
            }
            .padding(.horizontal, Spacing.l)
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: "Continue", style: .blueGlass) {
                    viewModel.setFirstName(firstName)
                    onNext()
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, Spacing.m)
            }
        }
        .onAppear {
            firstName = viewModel.firstName
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                isNameFocused = true
            }
        }
    }
}
