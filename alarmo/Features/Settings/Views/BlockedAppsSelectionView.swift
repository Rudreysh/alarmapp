import SwiftUI

#if canImport(FamilyControls)
import FamilyControls
#endif

struct BlockedAppsSelectionView: View {
    @StateObject private var authManager = ScreenTimeAuthorizationManager.shared
    @StateObject private var shieldManager = AppShieldManager.shared
    @ObservedObject private var settings = SettingsStore.shared
    @State private var showAppLists = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Phone Lock Permission")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Text(authManager.isAuthorized ? "Enabled" : "Required")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Colors.textSecondary)
            }

            Button {
                Task { await authManager.requestAuthorization() }
            } label: {
                HStack {
                    Image(systemName: "app.badge")
                    Text(authManager.isAuthorized ? "Screen Time access granted" : "Enable Screen Time access")
                    Spacer()
                    if !authManager.isAuthorized {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                }
                .foregroundColor(.white)
                .padding(12)
                .background(Colors.cardSurface)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .disabled(authManager.isAuthorized)

            Button {
                showAppLists = true
            } label: {
                HStack {
                    Text("Blocked Apps")
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                    Text("\(shieldManager.selectedAppCount(from: settings.blockedAppsSelectionData)) selected")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Colors.textSecondary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(Colors.textSecondary)
                }
                .foregroundColor(.white)
                .padding(12)
                .background(Colors.cardSurface)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .disabled(!authManager.isAuthorized)

            if authManager.isAuthorized {
                Text("Strict lock mode: while focus/alarm enforcement is active, all apps are locked until the timer ends or alarm rules are satisfied.")
                    .font(.caption)
                    .foregroundColor(Colors.textSecondary)
            }

            if !authManager.isAuthorized {
                Text(authManager.statusMessage ?? "App blocking requires Screen Time permission. Focus/alarm will still run without blocking.")
                    .font(.caption)
                    .foregroundColor(Colors.textSecondary)
            }
        }
        .onAppear {
            authManager.refreshStatus()
        }
        .sheet(isPresented: $showAppLists) {
            AppListsView()
        }
    }
}
