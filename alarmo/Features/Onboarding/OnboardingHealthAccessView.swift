import SwiftUI
import HealthKit

struct OnboardingHealthAccessView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onNext: () -> Void
    
    @State private var isRequesting = false
    @State private var showHealthPrompt = false
    @State private var turnOnAll = true
    @State private var readSteps = true
    @State private var readDistance = true
    @State private var readCycling = true
    @State private var readSleep = true
    @State private var readWater = true
    @State private var readStanding = true
    @State private var readMindfulness = true
    @State private var animateIn = false

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            
            VStack(spacing: 0) {
                ProgressHeader(step: 9, total: AppConstants.onboardingTotalSteps)
                    .padding(.horizontal, Spacing.l)
                    .padding(.top, Spacing.m)
                    .padding(.bottom, Spacing.s)
                
                Spacer()
                
                VStack(alignment: .center, spacing: 14) {
                    PermissionHeroIcon(
                        systemName: "heart.fill",
                        tint: Colors.accentRed
                    )
                        .padding(.bottom, 10)
                    
                    Text("Permission to Access Apple Health")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text("Awayk can read Apple Health data used by your habits: steps, walking/running distance, cycling distance, sleep, hydration, standing time, and mindfulness.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Colors.textSecondary)
                        .lineSpacing(2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Screen Time permissions are requested separately in the Screen Time step.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Colors.textSecondary.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, Spacing.l)
                .frame(maxWidth: .infinity, alignment: .center)
                .permissionEntrance(animateIn)
                
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
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            
            if showHealthPrompt {
                customHealthOverlay
                    .zIndex(1)
                    .transition(.move(edge: .bottom))
            }
            
            if isRequesting {
                Color.black.opacity(0.40).ignoresSafeArea()
                    .zIndex(2)
                PermissionAnimatedLoadingCard(title: "Requesting Health Access")
                .zIndex(3)
            }
        }
        .onAppear {
            animateIn = true
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
                            
                            Text("\"Awayk\" would like to read your Health data.")
                                .font(.system(size: 17, weight: .regular))
                                .foregroundColor(Color.white.opacity(0.7))
                        }
                        
                        Button {
                            turnOnAll.toggle()
                            readSteps = turnOnAll
                            readDistance = turnOnAll
                            readCycling = turnOnAll
                            readSleep = turnOnAll
                            readWater = turnOnAll
                            readStanding = turnOnAll
                            readMindfulness = turnOnAll
                        } label: {
                            Text(turnOnAll ? "Turn Off All" : "Turn On All")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(Colors.accentBlue)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                        }
                        
                        healthPermissionToggleSection(
                            icon: "figure.walk",
                            title: "Steps",
                            explanation: "App Explanation: Awayk reads your daily step count to keep step-based habits in sync.",
                            isOn: $readSteps
                        )

                        healthPermissionToggleSection(
                            icon: "figure.walk.motion",
                            title: "Walking + Running Distance",
                            explanation: "App Explanation: Awayk reads walking/running distance for movement-based habits.",
                            isOn: $readDistance
                        )

                        healthPermissionToggleSection(
                            icon: "bicycle",
                            title: "Cycling Distance",
                            explanation: "App Explanation: Awayk reads cycling distance for bike and ride habits.",
                            isOn: $readCycling
                        )

                        healthPermissionToggleSection(
                            icon: "bed.double.fill",
                            title: "Sleep Analysis",
                            explanation: "App Explanation: Awayk reads sleep duration for sleep and recovery habits.",
                            isOn: $readSleep
                        )

                        healthPermissionToggleSection(
                            icon: "drop.fill",
                            title: "Water Intake",
                            explanation: "App Explanation: Awayk reads hydration intake to update drink-water habits.",
                            isOn: $readWater
                        )

                        healthPermissionToggleSection(
                            icon: "figure.stand",
                            title: "Standing Time",
                            explanation: "App Explanation: Awayk reads stand time for standing and posture habits.",
                            isOn: $readStanding
                        )

                        healthPermissionToggleSection(
                            icon: "brain.head.profile",
                            title: "Mindfulness",
                            explanation: "App Explanation: Awayk reads mindful-session minutes for meditation habits.",
                            isOn: $readMindfulness
                        )
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
                            let categories = selectedHealthCategories()
                            let _ = await HealthKitManager.shared.requestAuthorization(for: categories)
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
        .onChange(of: readSteps) { _, _ in updateTurnOnAllState() }
        .onChange(of: readDistance) { _, _ in updateTurnOnAllState() }
        .onChange(of: readCycling) { _, _ in updateTurnOnAllState() }
        .onChange(of: readSleep) { _, _ in updateTurnOnAllState() }
        .onChange(of: readWater) { _, _ in updateTurnOnAllState() }
        .onChange(of: readStanding) { _, _ in updateTurnOnAllState() }
        .onChange(of: readMindfulness) { _, _ in updateTurnOnAllState() }
    }
    
    private func updateTurnOnAllState() {
        turnOnAll = readSteps && readDistance && readCycling && readSleep && readWater && readStanding && readMindfulness
    }

    private func selectedHealthCategories() -> [String] {
        var categories: [String] = []
        if readSteps || readDistance { categories.append("activity") }
        if readCycling { categories.append("cycling") }
        if readSleep { categories.append("sleep") }
        if readWater { categories.append("water") }
        if readStanding { categories.append("standing") }
        if readMindfulness { categories.append("mindfulness") }
        return Array(Set(categories))
    }

    private func healthPermissionToggleSection(
        icon: String,
        title: String,
        explanation: String,
        isOn: Binding<Bool>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Allow \"Awayk\" to read")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color.white.opacity(0.7))
                .padding(.horizontal, 4)

            HStack {
                Image(systemName: icon)
                    .foregroundColor(Colors.accentBlue)
                    .font(.system(size: 20))
                    .frame(width: 30)
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .tint(.green)
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)

            Text(explanation)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(Color.white.opacity(0.5))
                .padding(.horizontal, 4)
        }
    }
}
