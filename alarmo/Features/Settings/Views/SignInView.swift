import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @ObservedObject var store = SettingsStore.shared
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) private var openURL
    @State private var alertMessage: String?
    
    private let termsURL = URL(string: "https://alarmo.app/terms")!
    private let privacyURL = URL(string: "https://alarmo.app/privacy")!
    
    var body: some View {
        ZStack {
            SettingsGlassBackground()
            
            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Spacer()
                }
                .padding()
                
                Spacer()
                
                VStack(spacing: 12) {
                    Image(systemName: "icloud.and.arrow.up.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.white)
                        .padding(.bottom, 8)
                    
                    Text("Keep your record safe by signing in")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 40)
                
                Spacer()
                
                VStack(spacing: 20) {
                    SignInWithAppleButton(.continue) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        handleSignIn(result)
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .clipShape(Capsule())
                    
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
            let appleUserId = credential.user
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            if let data = appleUserId.data(using: .utf8) {
                KeychainHelper.shared.save(data, service: "com.alarmo.auth", account: "appleUserId")
            }
            store.isSignedIn = true
            store.appleUserId = appleUserId
            dismiss()
        case .failure(let error):
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                return
            }
            alertMessage = error.localizedDescription
        }
    }
}
