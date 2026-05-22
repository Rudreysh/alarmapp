import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @ObservedObject var store = SettingsStore.shared
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme
    @State private var alertMessage: String?
    
    private let termsURL = URL(string: "https://alarmo.app/terms")!
    private let privacyURL = URL(string: "https://alarmo.app/privacy")!
    private var canUseAppleSignIn: Bool { EntitlementInspector.hasAppleSignInAccess }
    private var isLightMode: Bool { colorScheme == .light }
    
    var body: some View {
        ZStack {
            SettingsGlassBackground()
            
            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Colors.textPrimary)
                    }
                    Spacer()
                }
                .padding()
                
                Spacer()
                
                VStack(spacing: 12) {
                    Image(systemName: "icloud.and.arrow.up.fill")
                        .font(.system(size: 64))
                        .foregroundColor(Colors.textPrimary)
                        .padding(.bottom, 8)
                    
                    Text(store.isSignedIn ? "You're signed in" : "Keep your record safe by signing in")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                        .multilineTextAlignment(.center)

                    if store.isSignedIn {
                        Text(store.profileDisplayName)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Colors.textSecondary)

                        let email = store.appleEmail.trimmingCharacters(in: .whitespacesAndNewlines)
                        Text(email.isEmpty ? "Email not available" : email)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Colors.textSecondary)
                    }
                }
                .padding(.horizontal, 40)
                
                Spacer()
                
                VStack(spacing: 20) {
                    if store.isSignedIn {
                        Button {
                            store.signOutAppleAccount()
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Text("Sign Out")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(isLightMode ? Colors.textPrimary : .white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(isLightMode ? Color.black.opacity(0.08) : Color.white.opacity(0.18))
                                .clipShape(Capsule())
                        }
                    } else {
                        if canUseAppleSignIn {
                            SignInWithAppleButton(.continue) { request in
                                request.requestedScopes = [.fullName, .email]
                            } onCompletion: { result in
                                handleSignIn(result)
                            }
                            .signInWithAppleButtonStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .clipShape(Capsule())
                        } else {
                            Button {
                                alertMessage = configurationIssueMessage()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "applelogo")
                                        .font(.system(size: 22, weight: .semibold))
                                    Text("Continue with Apple")
                                        .font(.system(size: 18, weight: .bold))
                                }
                                .foregroundColor(.black.opacity(0.65))
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.white.opacity(0.8))
                                .clipShape(Capsule())
                            }
                        }
                    }
                    
                    VStack(spacing: 4) {
                        Text("By proceeding, you are agreeing to our")
                        HStack(spacing: 4) {
                            Button("Terms & Conditions") {
                                openURL(termsURL)
                            }
                            Text("and")
                            Button("Privacy Policy.") {
                                openURL(privacyURL)
                            }
                        }
                    }
                    .font(.system(size: 13))
                    .foregroundColor(Colors.textSecondary)
                    .accentColor(SettingsPalette.accent)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 20)
            }
        }
        .alert("Sign In Failed", isPresented: Binding(
            get: { alertMessage != nil },
            set: { newValue in
                if !newValue { alertMessage = nil }
            }
        )) {
            Button("OK", role: .cancel) { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "")
        }
    }
    
    private func handleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                alertMessage = "Could not read your Apple account credential."
                return
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            store.completeAppleSignIn(with: credential)
            dismiss()
        case .failure(let error):
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                return
            }
            alertMessage = friendlyMessage(for: error)
        }
    }

    private func friendlyMessage(for error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == ASAuthorizationError.errorDomain && nsError.code == ASAuthorizationError.Code.unknown.rawValue {
            return configurationIssueMessage()
        }
        return error.localizedDescription
    }

    private func configurationIssueMessage() -> String {
        """
        Apple Sign In is not available for this build yet.

        Fix checklist:
        1) Xcode target -> Signing & Capabilities -> add "Sign In with Apple".
        2) In Apple Developer, enable Sign In with Apple for bundle id \(Bundle.main.bundleIdentifier ?? "your.bundle.id").
        3) Regenerate provisioning profile, clean build, reinstall app.
        4) Ensure iPhone is signed into Apple ID (iCloud).
        """
    }
}
