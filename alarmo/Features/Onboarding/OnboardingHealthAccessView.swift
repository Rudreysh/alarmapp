import SwiftUI
import HealthKit

struct OnboardingHealthAccessView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onNext: () -> Void
    
    @State private var isRequesting = false
    @State private var showHealthPrompt = false
    @State private var turnOnAll = false
    @State private var writeSleep = false
    @State private var readSleep = false

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            
            VStack(spacing: 0) {
                ProgressHeader(step: 7, total: AppConstants.onboardingTotalSteps)
                    .padding(.horizontal, Spacing.l)
                    .padding(.top, Spacing.m)
                    .padding(.bottom, Spacing.s)
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 16) {
                    // Custom Icon
                    Image(systemName: "heart.fill")
                        .font(.system(size: 60, weight: .semibold))
                        .foregroundColor(Colors.accentRed)
                        .padding(24)
                        .background(Colors.cardSurface)
                        .cornerRadius(24)
                        .padding(.bottom, 12)
                    
                    Text("Permission to Access Apple Health")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text("Alarmo can update the sleep category in Apple Health so that you can share your sleep data with other apps and services.")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(Colors.textSecondary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 32)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
                
                // Bottom Buttons
                HStack(spacing: 16) {
                    Button(action: onNext) {
                        Text("Skip")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(32)
                    }
                    .disabled(isRequesting)
                    
                    PrimaryButton(title: "Continue", style: .blueGlass) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showHealthPrompt = true
                        }
                    }
                    .disabled(isRequesting)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            }
            
            if showHealthPrompt {
                customHealthOverlay
                    .zIndex(1)
                    .transition(.move(edge: .bottom))
            }
            
            if isRequesting {
                Color.black.opacity(0.40).ignoresSafeArea()
                    .zIndex(2)
                VStack(spacing: 10) {
                    ProgressView().tint(Colors.accentTeal)
                    Text("Requesting Health Access...")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(Colors.cardSurface)
                .cornerRadius(14)
                .zIndex(3)
            }
        }
    }
    
    private var customHealthOverlay: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.6).ignoresSafeArea()

            VStack(spacing: 0) {
                // Top handle
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)
                
                Text("Health Access")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 12)
                    .padding(.bottom, 20)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Health")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("\"Alarmo\" would like to access and update your Health data.")
                                .font(.system(size: 17, weight: .regular))
                                .foregroundColor(Color.white.opacity(0.7))
                        }
                        
                        Button {
                            turnOnAll.toggle()
                            writeSleep = turnOnAll
                            readSleep = turnOnAll
                        } label: {
                            Text(turnOnAll ? "Turn Off All" : "Turn On All")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(Colors.accentBlue)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Allow \"Alarmo\" to write")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color.white.opacity(0.7))
                                .padding(.horizontal, 4)
                            
                            HStack {
                                Image(systemName: "bed.double.fill")
                                    .foregroundColor(Colors.accentBlue)
                                    .font(.system(size: 20))
                                    .frame(width: 30)
                                Text("Sleep")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.white)
                                Spacer()
                                Toggle("", isOn: $writeSleep)
                                    .labelsHidden()
                                    .tint(.green)
                            }
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                            
                            Text("App Explanation: Alarmo will update your Apple Health data with the sleep readings recorded in the app")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(Color.white.opacity(0.5))
                                .padding(.horizontal, 4)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Allow \"Alarmo\" to read")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color.white.opacity(0.7))
                                .padding(.horizontal, 4)
                            
                            HStack {
                                Image(systemName: "bed.double.fill")
                                    .foregroundColor(Colors.accentBlue)
                                    .font(.system(size: 20))
                                    .frame(width: 30)
                                Text("Sleep")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.white)
                                Spacer()
                                Toggle("", isOn: $readSleep)
                                    .labelsHidden()
                                    .tint(.green)
                            }
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                            
                            Text("App Explanation: Alarmo requires access to Health data in order to perform sleep tracking.")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(Color.white.opacity(0.5))
                                .padding(.horizontal, 4)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 20)
                }
                
                // Bottom Fixed Actions
                VStack(spacing: 12) {
                    Button {
                        withAnimation { showHealthPrompt = false }
                        Task {
                            isRequesting = true
                            let _ = await HealthKitManager.shared.requestAuthorization(for: "sleep")
                            isRequesting = false
                            onNext()
                        }
                    } label: {
                        Text("Allow")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Colors.accentBlue)
                            .cornerRadius(16)
                    }
                    
                    Button {
                        withAnimation { showHealthPrompt = false }
                        onNext()
                    } label: {
                        Text("Don't Allow")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(16)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 34)
                .padding(.top, 16)
            }
            .frame(maxHeight: 700)
            .background(Color(red: 0.12, green: 0.12, blue: 0.12))
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .edgesIgnoringSafeArea(.bottom)
        }
        .onChange(of: writeSleep) { _, _ in updateTurnOnAllState() }
        .onChange(of: readSleep) { _, _ in updateTurnOnAllState() }
    }
    
    private func updateTurnOnAllState() {
        if writeSleep && readSleep {
            turnOnAll = true
        } else {
            turnOnAll = false
        }
    }
}
