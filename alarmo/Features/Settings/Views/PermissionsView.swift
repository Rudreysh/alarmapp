import SwiftUI
import HealthKit
import AVFoundation
import CoreMotion
import UserNotifications
import FamilyControls

struct PermissionsView: View {
    @State private var showAboutPermissions = false
    
    @State private var healthAuthStatus: Bool = false
    @State private var micAuthStatus: Bool = false
    @State private var motionAuthStatus: Bool = false
    @State private var notificationAuthStatus: Bool = false
    @State private var screenTimeAuthStatus: Bool = false
    
    @State private var showScreenTimePrePrompt = false
    
    // CoreMotion doesn't have a simple synchronous auth status check, so we query it async
    let motionManager = CMMotionActivityManager()
    
    var body: some View {
        ZStack {
            SettingsGlassBackground()
            
            ScrollView {
                VStack(spacing: 24) {
                    
                    // About permissions Row
                    Button(action: {
                        showAboutPermissions = true
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                            Text("About permissions")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Toggles / Statuses
                    SettingsCard {
                        // Apple Health
                        PermissionRow(
                            title: "Apple Health",
                            subtitle: "To turn on, open the Apple Health app > Sharing > Apps > Alarmo",
                            iconName: "heart.fill",
                            iconBgColor: Colors.accentRed,
                            isOn: $healthAuthStatus,
                            isLast: false,
                            action: { requestHealth() }
                        )
                        
                        // Microphone
                        PermissionRow(
                            title: "Microphone",
                            subtitle: "To turn on, go to iPhone Settings > Alarmo > Microphone",
                            iconName: "mic.fill",
                            iconBgColor: Colors.accentTeal,
                            isOn: $micAuthStatus,
                            isLast: false,
                            action: { requestMicrophone() }
                        )
                        
                        // Motion data
                        PermissionRow(
                            title: "Motion data",
                            subtitle: "To turn on, go to iPhone Settings > Alarmo > Motion & Fitness",
                            iconName: "figure.walk",
                            iconBgColor: Colors.accentOrange,
                            isOn: $motionAuthStatus,
                            isLast: false,
                            action: { requestMotion() }
                        )
                        
                        // Notifications
                        PermissionRow(
                            title: "Notifications",
                            subtitle: "To turn on, go to iPhone Settings > Notifications > Alarmo",
                            iconName: "bell.badge.fill",
                            iconBgColor: Colors.accentBlue,
                            isOn: $notificationAuthStatus,
                            isLast: false,
                            action: { requestNotifications() }
                        )
                        
                        // Screen Time
                        PermissionRow(
                            title: "Screen Time",
                            subtitle: "To turn on, go to iPhone Settings > Screen Time > Alarmo",
                            iconName: "hourglass.circle.fill",
                            iconBgColor: .purple,
                            isOn: $screenTimeAuthStatus,
                            isLast: true,
                            action: { handleScreenTimeToggle() }
                        )
                    }
                }
            }
            
            // Custom Pre-Prompt Overlay
            if showScreenTimePrePrompt {
                Color.black.opacity(0.6).ignoresSafeArea()
                    .onTapGesture {
                        withAnimation { showScreenTimePrePrompt = false }
                    }
                
                VStack(spacing: 20) {
                    Text("\"Alarmo\" Would Like to Access Screen Time")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                    
                    Text("Providing \"Alarmo\" access to Screen Time may allow it to see your activity data, restrict content, and limit the usage of apps and websites.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundColor(Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    HStack(spacing: 12) {
                        Button("Don't Allow") {
                            withAnimation { showScreenTimePrePrompt = false }
                        }
                        .font(.system(size: 16, weight: .medium))
                        .frame(height: 48)
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.1))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        
                        Button("Continue") {
                            withAnimation { showScreenTimePrePrompt = false }
                            requestScreenTime() // Trigger the real Apple prompt
                        }
                        .font(.system(size: 16, weight: .bold))
                        .frame(height: 48)
                        .frame(maxWidth: .infinity)
                        .background(Colors.accentBlue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.top, 8)
                }
                .padding(24)
                .background(Colors.cardSurface)
                .cornerRadius(20)
                .padding(.horizontal, 40)
                // Add appShadow
                .appShadow(Shadows.card)
                .transition(.scale.combined(with: .opacity))
                .zIndex(100)
            }
        }
        .navigationTitle("Permissions")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            checkStatuses()
        }
        // Run check when returning to app
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            checkStatuses()
        }
        .sheet(isPresented: $showAboutPermissions) {
            AboutPermissionsView()
        }
    }
    
    // MARK: - Status Checking
    private func checkStatuses() {
        // Health
        if HKHealthStore.isHealthDataAvailable() {
            let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
            healthAuthStatus = HKHealthStore().authorizationStatus(for: sleepType) == .sharingAuthorized
        }
        
        // Microphone
        micAuthStatus = AVAudioSession.sharedInstance().recordPermission == .granted
        
        // Motion
        // Since motion auth status is .authorized/.denied/.notDetermined
        motionAuthStatus = CMMotionActivityManager.authorizationStatus() == .authorized
        
        // Notifications
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationAuthStatus = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
            }
        }
        
        // Screen Time
        if #available(iOS 15.0, *) {
            screenTimeAuthStatus = AuthorizationCenter.shared.authorizationStatus == .approved
        }
    }
    
    // MARK: - Request Logic
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    private func requestHealth() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let store = HKHealthStore()
        
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        // Need to request some common types based on the prompt description
        let typesToShare: Set = [sleepType]
        let typesToRead: Set = [sleepType]
        
        store.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            DispatchQueue.main.async {
                self.checkStatuses()
                if !success {
                    // It won't prompt again if denied, open settings
                    self.openSettings()
                }
            }
        }
    }
    
    private func requestMicrophone() {
        let status = AVAudioSession.sharedInstance().recordPermission
        switch status {
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async {
                    self.checkStatuses()
                }
            }
        default:
            // If denied or already granted but user toggled
            openSettings()
        }
    }
    
    private func requestMotion() {
        let status = CMMotionActivityManager.authorizationStatus()
        switch status {
        case .notDetermined:
            // We need to actually start an update to trigger the prompt
            motionManager.startActivityUpdates(to: .main) { _ in
                self.motionManager.stopActivityUpdates()
                self.checkStatuses()
            }
        default:
            openSettings()
        }
    }
    
    private func requestNotifications() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus == .notDetermined {
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                        DispatchQueue.main.async {
                            self.checkStatuses()
                        }
                    }
                } else {
                    self.openSettings()
                }
            }
        }
    }
    
    private func handleScreenTimeToggle() {
        if #available(iOS 15.0, *) {
            if AuthorizationCenter.shared.authorizationStatus == .notDetermined {
                withAnimation {
                    showScreenTimePrePrompt = true
                }
            } else if AuthorizationCenter.shared.authorizationStatus == .denied {
                 // Already denied, so open settings
                 openSettings()
            } else {
                 requestScreenTime()
            }
        } else {
            openSettings()
        }
    }
    
    private func requestScreenTime() {
        if #available(iOS 15.0, *) {
            Task {
                do {
                    try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                    DispatchQueue.main.async {
                        self.checkStatuses()
                    }
                } catch {
                    DispatchQueue.main.async {
                        print("Screen Time Permission Error: \(error.localizedDescription)")
                        self.openSettings()
                    }
                }
            }
        } else {
             openSettings()
        }
    }
}

// Custom Row Component for Permissions
struct PermissionRow: View {
    let title: String
    var subtitle: String? = nil
    let iconName: String
    let iconBgColor: Color
    @Binding var isOn: Bool
    let isLast: Bool
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconBgColor)
                    .frame(width: 32, height: 32)
                Image(systemName: iconName)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
            }
            .padding(.top, subtitle != nil ? 4 : 0) // Align better with multiline
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            Spacer()
            
            // Toggle
            Toggle("", isOn: Binding(
                get: { isOn },
                set: { _ in
                    // Instead of letting SwiftUI instantly flip the state, intercept it:
                    action()
                }
            ))
            .labelsHidden()
            .tint(Colors.accentTeal) // Optional: If you want to use teal
        }
        .padding(16)
        
        if !isLast {
            Divider()
                .background(Color.white.opacity(0.1))
                .padding(.leading, 64)
        }
    }
}


// MARK: - About Permissions View
struct AboutPermissionsView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                SettingsGlassBackground()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        
                        // Apple Health
                        PermissionInfoSection(
                            title: "Apple Health",
                            text: """
                            Alarmo can update the Apple Health 'Sleep' category to register the Time Asleep and Time in Bed for each sleep session detected. For this functionality, Alarmo requires both read and write access to the 'Sleep' category. Data from the 'Sleep' category may also be used to provide personalised insights and trend information.

                            If you want to track your sleep with an Apple Watch, Alarmo requires read access to the following categories: 'Heart Rate', 'Active Energy', 'Stand Hours', 'Stand Minutes', 'Walking Heart Rate Average', 'Mindful Minutes' and 'Steps'.

                            Alarmo can analyse and report important information about your heart rate and other heart-related metrics during sleep. This feature requires read access to the following Apple Health categories: 'Heart Rate', 'Heart Rate Variability', 'Resting Heart Rate', 'Walking Heart Rate Average' and the use of a paired Apple Watch.

                            Alarmo can analyse your blood oxygen levels and respiratory rate during sleep to provide a report of these metrics for each sleep session. This feature requires read access to the following Apple Health categories: 'Blood Oxygen', 'Respiratory Rate' and the use of a paired Apple Watch.

                            Alarmo can analyse data about the sounds in the environment that you sleep in and provide a report for each sleep session. This feature requires read and write access to the 'Environmental Sound Levels' Apple Health category and a compatible, paired Apple Watch.
                            """
                        )
                        
                        // Microphone
                        PermissionInfoSection(
                            title: "Microphone",
                            text: """
                            Alarmo requires permission to access the microphone to record and categorise the sounds you make during sleep or the sounds in your sleep environment (optional feature). In addition, it is required for sleep analysis on your iPhone/iPad and to ensure that the alarm will go off correctly on your iPhone/iPad.

                            If you want Alarmo to track your sleep automatically (just by wearing your Apple Watch during sleep), or you are using only Alarmo on the Apple Watch to track your sleep manually (by pressing 'Start'), then permission to access the microphone is not required.
                            """
                        )
                        
                        // Motion data
                        PermissionInfoSection(
                            title: "Motion data",
                            text: "Motion & fitness access is required for sleep tracking and analysis."
                        )
                        
                        // Notifications
                        PermissionInfoSection(
                            title: "Notifications",
                            text: """
                            Alarmo can send you a notification on the following occasions:

                            · When a new sleep session is detected.
                            · When you optimal bedtime is approaching.
                            · When a new sleep tip or insight is available.
                            · To report your wake-up mood.
                            All the notifications above can be enabled or disabled individually from Alarmo's settings.

                            Lastly, Alarmo can send you a notification when you receive a response from our support staff if you have contacted support.
                            """
                        )
                        
                        // Screen Time
                        PermissionInfoSection(
                            title: "Screen Time",
                            text: """
                            Alarmo can utilize Apple's Screen Time and Family Controls APIs to securely track your device usage data. 

                            This allows the app to limit access to distracting apps and help you build better digital habits directly from within Alarmo.
                            """
                        )
                    }
                    .padding(24)
                }
            }
            .navigationTitle("About permissions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
}

struct PermissionInfoSection: View {
    let title: String
    let text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2.bold())
                .foregroundColor(.white)
            
            Text(text)
                .font(.body)
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.leading)
                .lineSpacing(4)
            
            Divider()
                .background(Color.white.opacity(0.1))
                .padding(.top, 16)
        }
    }
}
