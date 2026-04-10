import SwiftUI
import StoreKit

struct PreventPowerOffView: View {
    @ObservedObject var settings = SettingsStore.shared
    @StateObject private var creditsManager = PenaltyCreditsManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var showInfo = false
    @State private var showGuide = false
    @State private var showPenaltyPicker = false
    @State private var showViolationCenter = false
    @State private var showCreditsSheet = false
    @State private var showAdvancedTriggers = false

    private var coreTriggerCount: Int {
        [
            settings.penaltyRules.triggerShutdownAttemptEnabled,
            settings.penaltyRules.triggerUninstallTamperEnabled,
            settings.penaltyRules.triggerSnoozeThresholdEnabled
        ]
        .filter { $0 }
        .count
    }

    private var advancedTriggerCount: Int {
        [
            settings.penaltyRules.triggerForceCloseEnabled,
            settings.penaltyRules.triggerForcedRestartEnabled,
            settings.penaltyRules.triggerBatteryDrainEnabled,
            settings.penaltyRules.triggerAirplaneModeAbuseEnabled,
            settings.penaltyRules.focusEarlyStopTriggersPenalty,
            settings.penaltyRules.focusOverrideTriggersPenalty,
            settings.penaltyRules.alarmMissionFailTriggersPenalty
        ]
        .filter { $0 }
        .count
    }

    var body: some View {
        ZStack {
            SettingsGlassBackground()
                .overlay(alignment: .topLeading) {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [SettingsPalette.accent.opacity(0.16), .clear],
                                center: .center,
                                startRadius: 10,
                                endRadius: 240
                            )
                        )
                        .frame(width: 280, height: 280)
                        .offset(x: -72, y: -86)
                }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    summaryCard

                    sectionCard(title: "Penalty Setup") {
                        SettingsActionRow(
                            title: "Penalty Amount",
                            subtitle: "Applied per confirmed violation",
                            trailingText: "\(settings.penaltyCurrency.symbol)\(settings.penaltyAmountEuro)",
                            icon: "eurosign.circle.fill",
                            iconColor: SettingsPalette.accent,
                            isLast: false
                        ) {
                            showPenaltyPicker = true
                        }

                        SettingsActionRow(
                            title: "Penalty Credits",
                            subtitle: "Current balance and credit packs",
                            trailingText: "\(settings.penaltyCurrency.symbol)\(settings.penaltyCreditsBalance)",
                            icon: "wallet.pass.fill",
                            iconColor: .green,
                            isLast: true
                        ) {
                            showCreditsSheet = true
                        }
                    }

                    sectionCard(title: "Core Triggers") {
                        PenaltyToggleRow(
                            title: "Phone shutdown attempt",
                            subtitle: "Penalize if shutdown is detected during alarm",
                            isOn: Binding(
                                get: { settings.penaltyRules.triggerShutdownAttemptEnabled },
                                set: { settings.penaltyRules.triggerShutdownAttemptEnabled = $0 }
                            ),
                            isLast: false
                        )

                        PenaltyToggleRow(
                            title: "App tamper / uninstall",
                            subtitle: "Best-effort check after returning to app",
                            isOn: Binding(
                                get: { settings.penaltyRules.triggerUninstallTamperEnabled },
                                set: { settings.penaltyRules.triggerUninstallTamperEnabled = $0 }
                            ),
                            isLast: false
                        )

                        PenaltyToggleRow(
                            title: "Snooze threshold exceeded",
                            subtitle: "Charges once per alarm session",
                            isOn: Binding(
                                get: { settings.penaltyRules.triggerSnoozeThresholdEnabled },
                                set: { settings.penaltyRules.triggerSnoozeThresholdEnabled = $0 }
                            ),
                            isLast: !settings.penaltyRules.triggerSnoozeThresholdEnabled
                        )

                        if settings.penaltyRules.triggerSnoozeThresholdEnabled {
                            Divider()
                                .background(Color.white.opacity(0.1))
                                .padding(.horizontal, 16)

                            StepperRow(
                                title: "Snooze threshold",
                                value: settings.snoozePenaltyThreshold,
                                range: 1...10,
                                valueFormatter: { "\($0) times" },
                                onDecrement: {
                                    if settings.snoozePenaltyThreshold > 1 {
                                        settings.snoozePenaltyThreshold -= 1
                                    }
                                },
                                onIncrement: {
                                    if settings.snoozePenaltyThreshold < 10 {
                                        settings.snoozePenaltyThreshold += 1
                                    }
                                }
                            )
                        }

                        SettingsActionRow(
                            title: "Advanced triggers",
                            subtitle: "Focus, restart, airplane mode, and policy rules",
                            trailingText: "\(advancedTriggerCount)/7",
                            icon: "slider.horizontal.3",
                            iconColor: SettingsPalette.accent,
                            isLast: true
                        ) {
                            showAdvancedTriggers = true
                        }
                    }

                    sectionCard(title: "Support & Audit") {
                        SettingsActionRow(
                            title: "Violation History",
                            subtitle: "Review pending and charged violations",
                            trailingText: "\(settings.violations.count)",
                            icon: "exclamationmark.triangle.fill",
                            iconColor: .orange,
                            isLast: false
                        ) {
                            showViolationCenter = true
                        }

                        SettingsActionRow(
                            title: "How penalties work",
                            subtitle: "Short explanation of detection and charge flow",
                            icon: "info.circle.fill",
                            iconColor: SettingsPalette.accent,
                            isLast: false
                        ) {
                            showInfo = true
                        }

                        SettingsActionRow(
                            title: "App Protection Guide",
                            subtitle: "Guided setup to harden alarms against bypass",
                            icon: "shield.checkered",
                            iconColor: .blue,
                            isLast: true
                        ) {
                            showGuide = true
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            if creditsManager.products.isEmpty {
                Task { await creditsManager.loadProducts() }
            }
        }
        .sheet(isPresented: $showInfo) {
            AccountabilityInfoView()
        }
        .sheet(isPresented: $showGuide) {
            AppProtectionGuideView()
        }
        .sheet(isPresented: $showPenaltyPicker) {
            PenaltyAmountPickerSheet(
                amount: $settings.penaltyAmountEuro,
                currency: Binding(
                    get: { settings.penaltyCurrency },
                    set: { settings.penaltyCurrency = $0 }
                )
            )
        }
        .sheet(isPresented: $showViolationCenter) {
            ViolationCenterView()
        }
        .sheet(isPresented: $showCreditsSheet) {
            PenaltyCreditsSheet()
        }
        .sheet(isPresented: $showAdvancedTriggers) {
            PenaltyAdvancedTriggersSheet()
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(SettingsPalette.accent)
                        .padding(9)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(SettingsPalette.accent.opacity(0.16))
                        )

                    Text("Accountability Penalty")
                        .font(.system(size: 32, weight: .black))
                        .foregroundColor(.white)
                }

                Text("Global penalty rules")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Colors.textSecondary)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Circle().fill(Color.white.opacity(0.06)))
            }
        }
        .padding(.horizontal, 4)
    }

    private var summaryCard: some View {
        HStack(spacing: 10) {
            summaryChip(
                title: "Amount",
                value: "\(settings.penaltyCurrency.symbol)\(settings.penaltyAmountEuro)",
                icon: "eurosign",
                tint: SettingsPalette.accent
            )
            summaryChip(
                title: "Core",
                value: "\(coreTriggerCount)/3",
                icon: "bolt.shield",
                tint: .orange
            )
            summaryChip(
                title: "Credits",
                value: "\(settings.penaltyCurrency.symbol)\(settings.penaltyCreditsBalance)",
                icon: "wallet.pass",
                tint: .green
            )
        }
    }

    private func summaryChip(title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
            }
            .foregroundColor(tint.opacity(0.95))

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .kerning(1.2)
                .foregroundColor(Colors.textTertiary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                content()
            }
            .background(
                LinearGradient(
                    colors: [
                        SettingsPalette.cardTop,
                        SettingsPalette.cardBottom
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            colors: [
                                SettingsPalette.accent.opacity(0.2),
                                .white.opacity(0.06),
                                SettingsPalette.accentDark.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: Colors.accentTeal.opacity(0.08), radius: 14, x: 0, y: 8)
        }
    }
}

private struct PenaltyToggleRow: View {
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool
    var isLast: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer()

                Toggle("", isOn: $isOn)
                    .toggleStyle(SwitchToggleStyle(tint: SettingsPalette.accent))
                    .labelsHidden()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            if !isLast {
                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.leading, 16)
            }
        }
    }
}

private struct StepperRow: View {
    let title: String
    let value: Int
    let range: ClosedRange<Int>
    let valueFormatter: (Int) -> String
    let onDecrement: () -> Void
    let onIncrement: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Text(valueFormatter(value))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Colors.textSecondary)
            }

            Spacer()

            HStack(spacing: 10) {
                Button(action: onDecrement) {
                    Image(systemName: "minus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .disabled(value <= range.lowerBound)

                Text("\(value)")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(minWidth: 28)

                Button(action: onIncrement) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.black)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(SettingsPalette.accent))
                }
                .disabled(value >= range.upperBound)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

struct PenaltyAdvancedTriggersSheet: View {
    @ObservedObject var settings = SettingsStore.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                SettingsGlassBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        SettingsCard {
                            PenaltyToggleRow(
                                title: "Force close during alarm",
                                subtitle: "Apply charge when user force-quits in alarm flow",
                                isOn: Binding(
                                    get: { settings.penaltyRules.triggerForceCloseEnabled },
                                    set: { settings.penaltyRules.triggerForceCloseEnabled = $0 }
                                ),
                                isLast: false
                            )
                            PenaltyToggleRow(
                                title: "Forced restart",
                                subtitle: "Charge when restart behavior indicates bypass attempt",
                                isOn: Binding(
                                    get: { settings.penaltyRules.triggerForcedRestartEnabled },
                                    set: { settings.penaltyRules.triggerForcedRestartEnabled = $0 }
                                ),
                                isLast: false
                            )
                            PenaltyToggleRow(
                                title: "Airplane mode abuse",
                                subtitle: "Penalize connectivity bypass attempts",
                                isOn: Binding(
                                    get: { settings.penaltyRules.triggerAirplaneModeAbuseEnabled },
                                    set: { settings.penaltyRules.triggerAirplaneModeAbuseEnabled = $0 }
                                ),
                                isLast: false
                            )
                            PenaltyToggleRow(
                                title: "Severe battery drain",
                                subtitle: "Penalty if battery collapse appears intentional",
                                isOn: Binding(
                                    get: { settings.penaltyRules.triggerBatteryDrainEnabled },
                                    set: { settings.penaltyRules.triggerBatteryDrainEnabled = $0 }
                                ),
                                isLast: true
                            )
                        }

                        SettingsCard {
                            PenaltyToggleRow(
                                title: "Focus session stopped early",
                                subtitle: "Charge when focus is ended before target time",
                                isOn: Binding(
                                    get: { settings.penaltyRules.focusEarlyStopTriggersPenalty },
                                    set: { settings.penaltyRules.focusEarlyStopTriggersPenalty = $0 }
                                ),
                                isLast: false
                            )
                            PenaltyToggleRow(
                                title: "Focus override block",
                                subtitle: "Charge when a block is bypassed in focus",
                                isOn: Binding(
                                    get: { settings.penaltyRules.focusOverrideTriggersPenalty },
                                    set: { settings.penaltyRules.focusOverrideTriggersPenalty = $0 }
                                ),
                                isLast: false
                            )
                            PenaltyToggleRow(
                                title: "Alarm mission failed",
                                subtitle: "Apply penalty when alarm mission times out",
                                isOn: Binding(
                                    get: { settings.penaltyRules.alarmMissionFailTriggersPenalty },
                                    set: { settings.penaltyRules.alarmMissionFailTriggersPenalty = $0 }
                                ),
                                isLast: true
                            )
                        }

                        SettingsCard {
                            StepperRow(
                                title: "Mission timeout",
                                value: settings.penaltyRules.alarmMissionTimeoutSeconds,
                                range: 30...600,
                                valueFormatter: { "\($0) sec" },
                                onDecrement: {
                                    let next = max(30, settings.penaltyRules.alarmMissionTimeoutSeconds - 30)
                                    settings.penaltyRules.alarmMissionTimeoutSeconds = next
                                },
                                onIncrement: {
                                    let next = min(600, settings.penaltyRules.alarmMissionTimeoutSeconds + 30)
                                    settings.penaltyRules.alarmMissionTimeoutSeconds = next
                                }
                            )
                            Divider()
                                .background(Color.white.opacity(0.1))
                                .padding(.horizontal, 16)
                            StepperRow(
                                title: "Low battery exempt",
                                value: settings.penaltyRules.lowBatteryExemptThresholdPercent,
                                range: 1...20,
                                valueFormatter: { "\($0)%" },
                                onDecrement: {
                                    let next = max(1, settings.penaltyRules.lowBatteryExemptThresholdPercent - 1)
                                    settings.penaltyRules.lowBatteryExemptThresholdPercent = next
                                },
                                onIncrement: {
                                    let next = min(20, settings.penaltyRules.lowBatteryExemptThresholdPercent + 1)
                                    settings.penaltyRules.lowBatteryExemptThresholdPercent = next
                                }
                            )
                            Divider()
                                .background(Color.white.opacity(0.1))
                                .padding(.horizontal, 16)
                            StepperRow(
                                title: "Emergency tap target",
                                value: settings.penaltyRules.emergencyCancellationTapTarget,
                                range: 100...1000,
                                valueFormatter: { "\($0) taps" },
                                onDecrement: {
                                    let next = max(100, settings.penaltyRules.emergencyCancellationTapTarget - 50)
                                    settings.penaltyRules.emergencyCancellationTapTarget = next
                                },
                                onIncrement: {
                                    let next = min(1000, settings.penaltyRules.emergencyCancellationTapTarget + 50)
                                    settings.penaltyRules.emergencyCancellationTapTarget = next
                                }
                            )
                        }

                        SettingsCard {
                            PenaltyToggleRow(
                                title: "Auto-approve first violation",
                                subtitle: "Grace policy for first offense",
                                isOn: Binding(
                                    get: { settings.penaltyRules.autoApproveFirstViolation },
                                    set: { settings.penaltyRules.autoApproveFirstViolation = $0 }
                                ),
                                isLast: false
                            )
                            PenaltyToggleRow(
                                title: "Auto-approve low battery cases",
                                subtitle: "Reduce false positives on low power events",
                                isOn: Binding(
                                    get: { settings.penaltyRules.autoApproveLowBattery },
                                    set: { settings.penaltyRules.autoApproveLowBattery = $0 }
                                ),
                                isLast: true
                            )
                        }
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Advanced Triggers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(SettingsPalette.accent)
                }
            }
        }
    }
}

struct PenaltyCreditsSheet: View {
    @ObservedObject var settings = SettingsStore.shared
    @StateObject private var creditsManager = PenaltyCreditsManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var purchasingProductId: String?

    var body: some View {
        NavigationStack {
            ZStack {
                SettingsGlassBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        SettingsCard {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Current Balance")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Colors.textSecondary)
                                    Text("\(settings.penaltyCurrency.symbol)\(settings.penaltyCreditsBalance)")
                                        .font(.system(size: 34, weight: .black, design: .rounded))
                                        .foregroundColor(SettingsPalette.accent)
                                }
                                Spacer()
                                Image(systemName: "wallet.pass.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(SettingsPalette.accent.opacity(0.8))
                            }
                            .padding(16)
                        }

                        SettingsCard {
                            if creditsManager.products.isEmpty {
                                SettingsActionRow(
                                    title: "Load credit packs",
                                    subtitle: "Refresh available App Store products",
                                    icon: "arrow.clockwise",
                                    iconColor: SettingsPalette.accent,
                                    isLast: true
                                ) {
                                    Task { await creditsManager.loadProducts() }
                                }
                            } else {
                                ForEach(Array(creditsManager.products.enumerated()), id: \.element.id) { index, product in
                                    SettingsActionRow(
                                        title: product.displayName,
                                        subtitle: purchasingProductId == product.id ? "Processing purchase..." : "Buy credit pack",
                                        trailingText: product.displayPrice,
                                        icon: "cart.fill",
                                        iconColor: .green,
                                        isLast: index == creditsManager.products.count - 1
                                    ) {
                                        Task {
                                            purchasingProductId = product.id
                                            _ = await creditsManager.purchase(product: product)
                                            purchasingProductId = nil
                                        }
                                    }
                                }
                            }
                        }

#if DEBUG
                        SettingsCard {
                            SettingsActionRow(
                                title: "Add test credits (debug)",
                                subtitle: "Adds \(settings.penaltyCurrency.symbol)25 for local QA",
                                trailingText: "Add",
                                icon: "testtube.2",
                                iconColor: .orange,
                                isLast: true
                            ) {
                                creditsManager.addTestCredits(25)
                            }
                        }
#endif
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Penalty Credits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(SettingsPalette.accent)
                }
            }
            .onAppear {
                if creditsManager.products.isEmpty {
                    Task { await creditsManager.loadProducts() }
                }
            }
        }
    }
}

struct PenaltyAmountPickerSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var amount: Int
    @Binding var currency: PenaltyCurrency

    var body: some View {
        NavigationView {
            ZStack {
                SettingsGlassBackground()
                VStack(spacing: 20) {
                    Text("Select penalty amount")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.top, 16)

                    HStack(spacing: 0) {
                        Picker("Amount", selection: $amount) {
                            ForEach(1...10, id: \.self) { value in
                                Text("\(value)").tag(value)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)

                        Picker("Currency", selection: $currency) {
                            ForEach(PenaltyCurrency.allCases, id: \.self) { code in
                                Text("\(code.symbol) \(code.rawValue)").tag(code)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                    }

                    Text("Current: \(currency.symbol)\(amount)")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Colors.accentTeal)
                    Spacer()
                }
                .padding(.horizontal, 16)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Colors.accentTeal)
                }
            }
        }
    }
}

struct AccountabilityInfoView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                SettingsGlassBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("How penalties work")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)

                        InfoBullet(text: "Penalties are evaluated only while an alarm session is active (ringing, snoozed, or mission flow).")
                        InfoBullet(text: "iOS does not provide perfect real-time uninstall detection, so tamper checks are best-effort and finalized when the app resumes.")
                        InfoBullet(text: "Snooze threshold penalties fire once per alarm session to avoid duplicate charges.")
                        InfoBullet(text: "Violation review and exemption flow is available from Violation History.")
                    }
                    .padding(20)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Colors.accentTeal)
                }
            }
        }
    }
}

private struct InfoBullet: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(SettingsPalette.accent)
                .frame(width: 6, height: 6)
                .padding(.top, 7)
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
