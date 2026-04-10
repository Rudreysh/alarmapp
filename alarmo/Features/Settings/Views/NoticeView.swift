import SwiftUI

struct NoticeView: View {
    private var appVersionLabel: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "Version \(version) (\(build))"
    }

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    legalSection
                    reliabilitySection
                    versionSection
                }
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.s)
                .padding(.bottom, Spacing.xl)
            }
        }
        .navigationTitle("Notice")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var legalSection: some View {
        NoticeSection(title: "Legal") {
            NavigationLink {
                PrivacyPolicyView()
            } label: {
                NoticeNavigationRow(
                    title: "Privacy Policy",
                    subtitle: "How your data is used and protected."
                )
            }
            .buttonStyle(.plain)

            Divider().background(Colors.cardStroke)

            NavigationLink {
                TermsConditionsView()
            } label: {
                NoticeNavigationRow(
                title: "Terms & Conditions",
                subtitle: "Rules and terms for using Alarmo."
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var reliabilitySection: some View {
        NoticeSection(title: "Important") {
            VStack(alignment: .leading, spacing: 10) {
                NoticeBullet(text: "Alarm reliability depends on iOS notification permissions, audio volume, Focus modes, and device power state.")
                NoticeBullet(text: "Keep notifications, background activity, and sound enabled for best wake-up reliability.")
                NoticeBullet(text: "Alarmo is not a medical or emergency alert system.")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }

    private var versionSection: some View {
        NoticeSection(title: "App") {
            HStack(spacing: 10) {
                Image(systemName: "app.badge")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Colors.accentTeal)
                Text(appVersionLabel)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Colors.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }
}

private struct NoticeSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Colors.textSecondary)
                .textCase(.uppercase)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                content
            }
            .background(Colors.cardSurface)
            .cornerRadius(18)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Colors.cardStroke, lineWidth: 1)
            )
            .appShadow(Shadows.card)
        }
    }
}

private struct NoticeNavigationRow: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Colors.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Colors.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Colors.accentTeal)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

private struct NoticeBullet: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Colors.accentTeal.opacity(0.9))
                .frame(width: 6, height: 6)
                .padding(.top, 6)

            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct LegalDocumentSection: Identifiable {
    let id = UUID()
    let title: String
    let body: String
}

private struct PrivacyPolicyView: View {
    private let lastUpdated = "March 9, 2026"
    private let sections: [LegalDocumentSection] = [
        LegalDocumentSection(
            title: "1. Data We Collect",
            body: "Alarmo stores alarm settings, app preferences, and optional profile data on your device. If you enable premium or account features, purchase and account metadata may be processed to deliver those features."
        ),
        LegalDocumentSection(
            title: "2. How We Use Data",
            body: "We use data to run alarms, save your settings, sync enabled features, improve reliability, and provide customer support when requested."
        ),
        LegalDocumentSection(
            title: "3. Notifications and Permissions",
            body: "Alarmo requires notification permission to trigger alarms. Optional permissions (microphone, motion, Screen Time, etc.) are used only for related features you choose to enable."
        ),
        LegalDocumentSection(
            title: "4. Data Sharing",
            body: "Alarmo does not sell personal data. Data may be shared only with service providers required for core functionality such as purchases, crash diagnostics, and cloud sync."
        ),
        LegalDocumentSection(
            title: "5. Data Retention and Deletion",
            body: "Most app data remains on-device until removed by you. You can reset app data from iOS settings or by deleting the app."
        ),
        LegalDocumentSection(
            title: "6. Contact",
            body: "For privacy requests, contact support@alarmo.app."
        )
    ]

    var body: some View {
        LegalDocumentView(
            title: "Privacy Policy",
            subtitle: "Last updated: \(lastUpdated)",
            sections: sections
        )
    }
}

private struct TermsConditionsView: View {
    private let lastUpdated = "March 9, 2026"
    private let sections: [LegalDocumentSection] = [
        LegalDocumentSection(
            title: "1. Acceptance",
            body: "By using Alarmo, you agree to these Terms and applicable Apple platform rules."
        ),
        LegalDocumentSection(
            title: "2. Intended Use",
            body: "Alarmo is a productivity and alarm application. It is not a medical device, emergency alert service, or safety-critical system."
        ),
        LegalDocumentSection(
            title: "3. Account and Purchases",
            body: "Some features may require sign-in or subscription. Billing, renewals, and refunds follow Apple App Store terms for your account region."
        ),
        LegalDocumentSection(
            title: "4. User Responsibilities",
            body: "You are responsible for maintaining device volume, permissions, Focus mode settings, and battery conditions needed for alarm reliability."
        ),
        LegalDocumentSection(
            title: "5. Prohibited Use",
            body: "You must not abuse, reverse engineer, interfere with service integrity, or use Alarmo in ways that violate applicable law."
        ),
        LegalDocumentSection(
            title: "6. Limitation of Liability",
            body: "Alarmo is provided on an as-is basis to the maximum extent allowed by law. Liability is limited for indirect or consequential damages."
        ),
        LegalDocumentSection(
            title: "7. Changes to Terms",
            body: "We may update these terms. Continued use after updates means you accept the revised version."
        )
    ]

    var body: some View {
        LegalDocumentView(
            title: "Terms & Conditions",
            subtitle: "Last updated: \(lastUpdated)",
            sections: sections
        )
    }
}

private struct LegalDocumentView: View {
    let title: String
    let subtitle: String
    let sections: [LegalDocumentSection]

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(Colors.textPrimary)
                        Text(subtitle)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Colors.textSecondary)
                    }
                    .padding(.horizontal, 4)

                    NoticeSection(title: "Document") {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(sections) { section in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(section.title)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Colors.textPrimary)
                                    Text(section.body)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(Colors.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                if section.id != sections.last?.id {
                                    Divider().background(Colors.cardStroke)
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                    }
                }
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.s)
                .padding(.bottom, Spacing.xl)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
