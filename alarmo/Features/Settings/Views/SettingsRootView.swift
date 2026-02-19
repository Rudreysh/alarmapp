import SwiftUI

struct SettingsRootView: View {
    @ObservedObject var store = SettingsStore.shared
    @StateObject var subManager = SubscriptionManager.shared
    @StateObject var coordinator = SettingsCoordinator()
    
    @State private var showSignIn = false
    @State private var showPro = false
    @State private var showPenalty = false
    
    var body: some View {
        NavigationStack(path: $coordinator.path) {
            ZStack {
                SettingsGlassBackground()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Settings")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.top, 10)
                        
                        // Account Section
                        SettingsCard {
                            SettingsActionRow(
                                title: store.isSignedIn ? "User_62831" : "Sign in to your account",
                                icon: "person.circle.fill",
                                iconColor: Colors.textSecondary,
                                isLast: false
                            ) {
                                showSignIn = true
                            }
                            
                            NavigationLink(destination: MyPointsView()) {
                                SettingsActionRow(
                                    title: "My points",
                                    trailingText: "\(store.points) P",
                                    icon: "p.circle.fill",
                                    iconColor: .orange,
                                    isLast: false
                                ) { }
                            }
                            .buttonStyle(.plain)
                            
                            SettingsActionRow(
                                title: "Pro",
                                trailingText: subManager.isPro ? "Subscribed" : "Not subscribed",
                                icon: "bolt.fill",
                                iconColor: .red,
                                isLast: false
                            ) {
                                showPro = true
                            }
                            
                            SettingsActionRow(
                                title: "Accountability Shield",
                                trailingText: store.accountabilityEnabled ? "on" : "off",
                                icon: "shield.fill",
                                iconColor: .green,
                                isLast: true
                            ) {
                                showPenalty = true
                            }
                        }
                        
                        // General Settings Group
                        SettingsCard {
                            SettingsActionRow(title: "Advanced alarm settings", isLast: false) {
                                coordinator.navigate(to: .advanced)
                            }
                            
                            SettingsActionRow(title: "Theme", isLast: false) {
                                coordinator.navigate(to: .theme)
                            }
                            
                            SettingsActionRow(title: "Sound output", trailingText: store.soundOutputMode.rawValue, isLast: false) {
                                coordinator.navigate(to: .soundOutput)
                            }
                            
                            SettingsActionRow(
                                title: "Notification setting",
                                subtitle: "Service notification • Promotion & update",
                                isLast: true
                            ) {
                                coordinator.navigate(to: .notification)
                            }
                        }
                        
                        // System Group
                        SettingsCard {
                            SettingsActionRow(
                                title: "System configuration",
                                subtitle: "App Language • Battery saving mode",
                                isLast: true
                            ) {
                                coordinator.navigate(to: .system)
                            }
                        }
                        
                        // Banner Placeholder
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            SettingsPalette.accentDark.opacity(0.92),
                                            SettingsPalette.accent.opacity(0.72),
                                            SettingsPalette.accentDark.opacity(0.95)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            
                            HStack {
                                Image(systemName: "bell.badge.fill")
                                    .foregroundColor(.white)
                                    .font(.title2)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Alarm didn't ring?")
                                        .font(.system(size: 13))
                                        .foregroundColor(.white.opacity(0.8))
                                    Text("Alarm optimization")
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .padding()
                        }
                        .frame(height: 72)
                        .padding(.horizontal, 16)
                        .onTapGesture {
                            coordinator.navigate(to: .optimization)
                        }
                        
                        // Info Group
                        VStack(alignment: .leading, spacing: 24) {
                            Group {
                                Button("Notice") { }
                                Button("FAQ") { 
                                    coordinator.navigate(to: .faq)
                                }
                                Button("Send feedback") { 
                                    if let url = URL(string: "mailto:support@alarmo.app") {
                                        UIApplication.shared.open(url)
                                    }
                                }
                            }
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 10)
                        
                    }
                    .padding(.bottom, AppConstants.tabBarHeight + Spacing.m)
                }
            }
            .navigationDestination(for: SettingsRoute.self) { route in
                switch route {
                case .advanced:
                    AdvancedSettingsView()
                case .theme:
                    ThemeSettingsView()
                case .soundOutput:
                    SoundOutputView()
                case .notification:
                    NotificationSettingsView()
                case .system:
                    SystemConfigurationView()
                case .faq:
                    FAQView()
                case .optimization:
                    AppProtectionGuideView()
                }
            }
        }
        .fullScreenCover(isPresented: $showSignIn) {
            SignInView()
        }
        .fullScreenCover(isPresented: $showPro) {
            ProView()
        }
        .fullScreenCover(isPresented: $showPenalty) {
            AccountabilityShieldSettingsView()
        }
    }
}

struct SimplePlaceholderView: View {
    let title: String
    
    var body: some View {
        ZStack {
            SettingsGlassBackground()
            Text("\(title) coming soon")
                .foregroundColor(Colors.textSecondary)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
