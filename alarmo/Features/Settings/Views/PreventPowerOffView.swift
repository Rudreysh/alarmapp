import SwiftUI
import StoreKit

struct PreventPowerOffView: View {
    @ObservedObject var settings = SettingsStore.shared
    @StateObject private var authManager = ScreenTimeAuthorizationManager.shared
    @StateObject private var creditsManager = PenaltyCreditsManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var showInfo = false
    @State private var showPenaltyPicker = false

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    SettingsCard {
                        SettingsCardToggleRow(
                            title: "Enable Accountability Shield",
                            subtitle: "Protect focus and alarm commitments",
                            isOn: $settings.accountabilityEnabled,
                            isLast: false
                        )

                        SettingsActionRow(
                            title: "Mode",
                            trailingText: settings.enforcementMode.rawValue,
                            isLast: false
                        ) {
                            cycleMode()
                        }

                        SettingsCardToggleRow(
                            title: "Block apps",
                            subtitle: "Uses Screen Time shield",
                            isOn: $settings.blockAppsEnabled,
                            isLast: false
                        )

                        SettingsCardToggleRow(
                            title: "Enable penalty credits",
                            subtitle: "Consumes credits when rules break",
                            isOn: $settings.penaltyEnabled,
                            isLast: false
                        )

                        SettingsActionRow(
                            title: "Penalty amount",
                            trailingText: "\(settings.penaltyCurrency.symbol)\(settings.penaltyAmountEuro) • \(settings.penaltyCurrency.rawValue)",
                            isLast: true
                        ) {
                            showPenaltyPicker = true
                        }
                    }

                    if settings.accountabilityEnabled {
                        SettingsCard {
                            BlockedAppsSelectionView()
                                .padding(16)

                            Divider().padding(.horizontal, 16).opacity(0.2)

                            VStack(alignment: .leading, spacing: 12) {
                                Text("Advanced rules")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white)

                                Stepper("Snooze threshold: \(settings.penaltyRules.alarmSnoozeThreshold)", value: Binding(
                                    get: { settings.penaltyRules.alarmSnoozeThreshold },
                                    set: { settings.penaltyRules.alarmSnoozeThreshold = max(1, $0) }
                                ), in: 1...10)
                                .foregroundColor(.white)

                                Stepper("Mission timeout: \(settings.penaltyRules.alarmMissionTimeoutSeconds)s", value: Binding(
                                    get: { settings.penaltyRules.alarmMissionTimeoutSeconds },
                                    set: { settings.penaltyRules.alarmMissionTimeoutSeconds = max(30, $0) }
                                ), in: 30...600, step: 15)
                                .foregroundColor(.white)
                            }
                            .padding(16)
                        }
                    }

                    SettingsCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Penalty credits")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                            Text("Balance: \(settings.penaltyCurrency.symbol)\(settings.penaltyCreditsBalance)")
                                .font(.system(size: 22, weight: .black))
                                .foregroundColor(Colors.accentTeal)
                            
                            Button("Add test credits (no card)") {
                                creditsManager.addTestCredits(25)
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Colors.accentTeal)

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

                    if !settings.accountabilityAuditEvents.isEmpty {
                        SettingsCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Penalty history")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)

                                ForEach(settings.accountabilityAuditEvents.suffix(10).reversed()) { event in
                                    HStack {
                                        Text(event.eventType.rawValue)
                                            .foregroundColor(.white)
                                        Spacer()
                                        Text("-\(settings.penaltyCurrency.symbol)\(event.amountEuro)")
                                            .foregroundColor(.red)
                                    }
                                    .font(.system(size: 14, weight: .medium))
                                }
                            }
                            .padding(16)
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            authManager.refreshStatus()
            if creditsManager.products.isEmpty {
                Task { await creditsManager.loadProducts() }
            }
        }
        .sheet(isPresented: $showInfo) {
            AccountabilityInfoView()
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
                Text("Accountability Shield")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                Text("Block distractions and enforce consequences")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Colors.textSecondary)
            }
            Spacer()
            Button {
                showInfo = true
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }

    private func cycleMode() {
        let all = EnforcementMode.allCases
        let index = all.firstIndex(of: settings.enforcementMode) ?? 0
        let next = all[(index + 1) % all.count]
        settings.enforcementMode = next
    }
}

struct PenaltyAmountPickerSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var amount: Int
    @Binding var currency: PenaltyCurrency
    
    var body: some View {
        NavigationView {
            ZStack {
                Colors.bgPrimary.ignoresSafeArea()
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
                Colors.bgPrimary.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 16) {
                    Text("How it works")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    Text("1. Enable Screen Time authorization.\n2. Choose apps to block during focus/alarm missions.\n3. Turn on penalty credits and set amount (€1-€10).\n4. If rules are broken, credits are consumed and logged.")
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
