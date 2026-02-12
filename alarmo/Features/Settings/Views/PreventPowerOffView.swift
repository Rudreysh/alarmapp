import SwiftUI
import StoreKit

struct PreventPowerOffView: View {
    @ObservedObject var settings = SettingsStore.shared
    @StateObject private var creditsManager = PenaltyCreditsManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var showInfo = false
    @State private var showGuide = false
    @State private var showPenaltyPicker = false

    var body: some View {
        ZStack {
            SettingsGlassBackground()
            .overlay(alignment: .topLeading) {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [SettingsPalette.accent.opacity(0.22), .clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 260
                        )
                    )
                    .frame(width: 320, height: 320)
                    .offset(x: -80, y: -90)
            }
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [SettingsPalette.accentDark.opacity(0.16), .clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 260
                        )
                    )
                    .frame(width: 320, height: 320)
                    .offset(x: 80, y: 120)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    shieldCard {
                        SettingsActionRow(
                            title: "Penalty Amount",
                            trailingText: "\(settings.penaltyCurrency.symbol)\(settings.penaltyAmountEuro)",
                            isLast: true
                        ) {
                            showPenaltyPicker = true
                        }
                    }

                    shieldCard {
                        SettingsCardToggleRow(
                            title: "Charge if phone shutdown attempted",
                            subtitle: "Uses active alarm lifecycle/tamper signals",
                            isOn: Binding(
                                get: { settings.penaltyRules.triggerShutdownAttemptEnabled },
                                set: { settings.penaltyRules.triggerShutdownAttemptEnabled = $0 }
                            ),
                            isLast: false
                        )

                        SettingsCardToggleRow(
                            title: "Charge if app uninstall/tamper during alarm",
                            subtitle: "Best effort detection, applied when app resumes",
                            isOn: Binding(
                                get: { settings.penaltyRules.triggerUninstallTamperEnabled },
                                set: { settings.penaltyRules.triggerUninstallTamperEnabled = $0 }
                            ),
                            isLast: false
                        )

                        SettingsCardToggleRow(
                            title: "Charge if snooze exceeds threshold",
                            subtitle: "Penalty fires once per alarm session",
                            isOn: Binding(
                                get: { settings.penaltyRules.triggerSnoozeThresholdEnabled },
                                set: { settings.penaltyRules.triggerSnoozeThresholdEnabled = $0 }
                            ),
                            isLast: !settings.penaltyRules.triggerSnoozeThresholdEnabled
                        )

                        if settings.penaltyRules.triggerSnoozeThresholdEnabled {
                            Divider().padding(.horizontal, 16).opacity(0.2)
                            HStack {
                                Text("Snooze threshold")
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(settings.snoozePenaltyThreshold) times")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(Colors.textSecondary)
                                Stepper(
                                    "",
                                    value: Binding(
                                        get: { settings.snoozePenaltyThreshold },
                                        set: { settings.snoozePenaltyThreshold = $0 }
                                    ),
                                    in: 1...10
                                )
                                .labelsHidden()
                                .tint(SettingsPalette.accent)
                            }
                            .padding(16)
                        }
                    }

                    shieldCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("How penalties work")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                            Text("Penalties are evaluated only while an alarm session is active (ringing/snoozed/mission flow). iOS cannot provide reliable real-time uninstall detection, so app uninstall checks use best-effort tamper signals and accountability on resume.")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Colors.textSecondary)

                            Button("How this works") { showInfo = true }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(SettingsPalette.accent)
                            Button("App Protection Guide") { showGuide = true }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(SettingsPalette.accent)
                        }
                        .padding(16)
                    }

                    shieldCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Penalty Credits")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                            Text("Balance: \(settings.penaltyCurrency.symbol)\(settings.penaltyCreditsBalance)")
                                .font(.system(size: 22, weight: .black))
                                .foregroundColor(SettingsPalette.accent)

                            Button("Add test credits (no card)") {
                                creditsManager.addTestCredits(25)
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(SettingsPalette.accent)

                            if creditsManager.products.isEmpty {
                                Button("Load credit packs") {
                                    Task { await creditsManager.loadProducts() }
                                }
                                .foregroundColor(.white)
                            } else {
                                ForEach(creditsManager.products, id: \.id) { product in
                                    Button {
                                        Task { _ = await creditsManager.purchase(product: product) }
                                    } label: {
                                        HStack {
                                            Text(product.displayName)
                                            Spacer()
                                            Text(product.displayPrice)
                                        }
                                        .foregroundColor(.white)
                                        .padding(10)
                                        .background(Colors.cardSurface)
                                        .cornerRadius(8)
                                    }
                                }
                            }
                        }
                        .padding(16)
                    }
                }
                .padding(16)
                .padding(.bottom, 30)
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
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(SettingsPalette.accent)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(SettingsPalette.accent.opacity(0.16))
                        )
                    Text("Accountability Shield")
                        .font(.system(size: 34, weight: .black))
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
            }
        }
    }

    @ViewBuilder
    private func shieldCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
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
            RoundedRectangle(cornerRadius: 26)
                .stroke(
                    LinearGradient(
                        colors: [
                            SettingsPalette.accent.opacity(0.22),
                            .white.opacity(0.06),
                            SettingsPalette.accentDark.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .shadow(color: Colors.accentTeal.opacity(0.08), radius: 14, x: 0, y: 8)
        .padding(.horizontal, 16)
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
                VStack(alignment: .leading, spacing: 16) {
                    Text("How it works")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    Text("Penalties apply only while an alarm session is active. You can customize triggers for shutdown attempts, uninstall/tamper signals, and snooze threshold abuse.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Colors.textSecondary)
                    Spacer()
                }
                .padding(20)
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
