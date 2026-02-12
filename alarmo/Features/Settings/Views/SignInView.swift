import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @ObservedObject var store = SettingsStore.shared
    @Environment(\.dismiss) var dismiss
    
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
                    Button(action: handleSignIn) {
                        HStack {
                            Image(systemName: "apple.logo")
                                .font(.title3)
                            Text("Continue with Apple")
                                .font(.system(size: 17, weight: .bold))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white)
                        .cornerRadius(28)
                    }
                    
                    VStack(spacing: 4) {
                        Text("By proceeding, you are agreeing to our")
                        HStack(spacing: 4) {
                            Button("Terms & Conditions") { }
                            Text("and")
                            Button("Privacy Policy.") { }
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
    }
    
    private func handleSignIn() {
        // ASAuthorizationAppleIDProvider implementation
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.performRequests()
        
        // Mock success for now
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            let mockUserId = "mock_apple_id_\(UUID().uuidString)"
            
            // Save to Keychain
            if let data = mockUserId.data(using: .utf8) {
                KeychainHelper.shared.save(data, service: "com.alarmo.auth", account: "appleUserId")
            }
            
            store.isSignedIn = true
            store.appleUserId = mockUserId
            dismiss()
        }
    }
}
