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
                    .fill(isNameFocused ? Colors.accentTeal : Colors.textSecondary.opacity(0.25))
                    .frame(height: isNameFocused ? 2 : 1)
                    .animation(.easeInOut(duration: 0.2), value: isNameFocused)
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
                .disabled(firstName.trimmingCharacters(in: .whitespaces).isEmpty)
                .scaleEffect(firstName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.96 : 1.0)
                .opacity(firstName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1.0)
                .animation(.spring(response: 0.38, dampingFraction: 0.72), value: firstName.trimmingCharacters(in: .whitespaces).isEmpty)
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
