import SwiftUI
import UIKit

/// Honest "maximum lockdown" guide. iOS does not let a consumer app prevent its own
/// deletion, so the only real anti-uninstall is Apple's own Screen Time restriction
/// "Don't Allow Removing Apps" behind a passcode the user doesn't hold. This walks the
/// user (or their accountability partner) through enabling it.
struct LockdownGuideView: View {
    @Environment(\.dismiss) private var dismiss

    private let steps: [(String, String)] = [
        ("1", "Open Settings → Screen Time."),
        ("2", "Tap “Content & Privacy Restrictions” and turn it on."),
        ("3", "Tap “App Store, Media & Purchases” → “Deleting Apps”."),
        ("4", "Choose “Don't Allow”. This app can no longer be deleted."),
        ("5", "Set a Screen Time passcode — ideally have a friend or partner enter it so you can't undo it yourself.")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Make blocking tamper-resistant")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(Colors.textPrimary)
                        Text("On iPhone, an app can't stop you from deleting it — only Apple's Screen Time can. These steps make the block impossible to escape by uninstalling.")
                            .font(.system(size: 14))
                            .foregroundColor(Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(steps, id: \.0) { step in
                            HStack(alignment: .top, spacing: 12) {
                                ZStack {
                                    Circle().fill(Colors.accentBlue.opacity(0.18)).frame(width: 28, height: 28)
                                    Text(step.0).font(.system(size: 14, weight: .bold)).foregroundColor(Colors.accentBlue)
                                }
                                Text(step.1)
                                    .font(.system(size: 15))
                                    .foregroundColor(Colors.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    Text("What this app already does")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Colors.textPrimary)
                    VStack(alignment: .leading, spacing: 8) {
                        bullet("Locked timers can't be ended early in the app.")
                        bullet("The block survives force-quit and reboot.")
                        bullet("If you reinstall, the lock resumes instead of resetting.")
                        bullet("Turning off Screen Time access while locked is recorded.")
                    }

                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text("Open Settings")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Capsule().fill(Colors.accentBlue))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .padding(22)
            }
            .background(SettingsGlassBackground().ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(Colors.accentGreen)
                .padding(.top, 2)
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}
