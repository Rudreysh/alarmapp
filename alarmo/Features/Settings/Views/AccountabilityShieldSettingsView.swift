import SwiftUI

// MARK: - Main View

struct AccountabilityShieldSettingsView: View {
    @ObservedObject var store = SettingsStore.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var showViolationCenter = false
    @State private var showEditPenalty = false
    @State private var shieldPulse = false
    @State private var ringRotation: Double = 0
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Reuse Settings background so this flow matches the rest of Settings.
                SettingsGlassBackground()
                
                // Ambient glow when shield is active
                if store.accountabilityEnabled {
                    RadialGradient(
                        colors: [
                            Colors.accentTeal.opacity(0.08),
                            Color.clear
                        ],
                        center: .top,
                        startRadius: 50,
                        endRadius: 400
                    )
                    .ignoresSafeArea()
                }
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        
                        // MARK: - Shield Hero
                        shieldHero
                            .padding(.top, 16)
                            .padding(.bottom, 32)
                        
                        // MARK: - Stake Card
                        stakeCard
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                        
                        // MARK: - Trigger Pills
                        triggerSection
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                            .opacity(store.accountabilityEnabled ? 1 : 0.6)
                            .disabled(!store.accountabilityEnabled)
                        
                        // MARK: - Violations
                        violationRow
                            .padding(.horizontal, 20)
                            .padding(.bottom, 32)
                        
                        Spacer(minLength: 60)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Text("Done")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Colors.accentTeal)
                    }
                }
            }
            .sheet(isPresented: $showViolationCenter) {
                ViolationCenterView()
            }
            .sheet(isPresented: $showEditPenalty) {
                PenaltyEditSheet()
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    shieldPulse = true
                }
                withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                    ringRotation = 360
                }
            }
        }
    }
    
    // MARK: - Shield Hero Section
    
    private var shieldHero: some View {
        VStack(spacing: 14) {
            ZStack {
                // Outer ring
                if store.accountabilityEnabled {
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [Colors.accentTeal.opacity(0.6), Colors.accentTeal.opacity(0), Colors.accentTeal.opacity(0.3), Colors.accentTeal.opacity(0)],
                                center: .center
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(ringRotation))
                }
                
                // Glow circle
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                (store.accountabilityEnabled ? Colors.accentTeal : Color.gray).opacity(shieldPulse ? 0.15 : 0.05),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 60
                        )
                    )
                    .frame(width: 110, height: 110)
                
                // Shield icon
                Image(systemName: store.accountabilityEnabled ? "shield.lefthalf.filled" : "shield.slash")
                    .font(.system(size: 52, weight: .medium))
                    .foregroundStyle(
                        store.accountabilityEnabled
                            ? LinearGradient(colors: [Colors.accentTeal, Color(red: 0, green: 0.55, blue: 0.65)], startPoint: .top, endPoint: .bottom)
                            : LinearGradient(colors: [Color.gray.opacity(0.5), Color.gray.opacity(0.3)], startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: store.accountabilityEnabled ? Colors.accentTeal.opacity(0.4) : .clear, radius: 20, x: 0, y: 8)
            }
            
            Text(store.accountabilityEnabled ? "FINE ACTIVE" : "FINE OFF")
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .kerning(3)
                .foregroundColor(store.accountabilityEnabled ? Colors.accentTeal : Color.gray)
        }
    }
    
    // MARK: - Stake Card
    
    private var stakeCard: some View {
        VStack(spacing: 0) {
            // Toggle row
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Penalty")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                    Text(store.accountabilityEnabled ? "Consequences are real" : "Master switch is off")
                        .font(.system(size: 13))
                        .foregroundColor(store.accountabilityEnabled ? Colors.textTertiary : Color.gray)
                }
                
                Spacer()
                
                Toggle("", isOn: $store.accountabilityEnabled)
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: Colors.accentTeal))
            }
            .padding(.horizontal, 22)
            .padding(.top, 22)
            .padding(.bottom, 20)
            
            VStack(spacing: 0) {
                // Divider line
                Rectangle()
                    .fill(Color.white.opacity(0.04))
                    .frame(height: 1)
                    .padding(.horizontal, 22)
                
                // Amount display
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(store.penaltyCurrency.symbol)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Colors.accentTeal)
                    Text("\(store.penaltyAmountEuro)")
                        .font(.system(size: 64, weight: .heavy))
                        .foregroundColor(.white)
                    Text(".00")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.35))
                    
                    Spacer()
                    
                    // Edit pill
                    Button(action: { showEditPenalty = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 12, weight: .bold))
                            Text("Edit")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 14)
                .padding(.bottom, 6)
                
                // Per cheat label
                HStack {
                    Text("per violation")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Colors.textTertiary)
                    Spacer()
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 22)
            }
            .opacity(store.accountabilityEnabled ? 1 : 0.6)
            .disabled(!store.accountabilityEnabled)
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(red: 0.07, green: 0.08, blue: 0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    store.accountabilityEnabled
                        ? Colors.accentTeal.opacity(0.15)
                        : Color.white.opacity(0.04),
                    lineWidth: 1
                )
        )
    }
    
    // MARK: - Trigger Section
    
    private var triggerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("TRIGGERS")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .kerning(2)
                .foregroundColor(Colors.textTertiary)
                .padding(.leading, 4)
            
            // Trigger toggles - vertical list
            VStack(spacing: 8) {
                TriggerChip(
                    icon: "power",
                    label: "Phone Shutdown",
                    color: .red,
                    isOn: Binding(
                        get: { store.triggerShutdownAttemptEnabled },
                        set: { store.triggerShutdownAttemptEnabled = $0 }
                    )
                )
                
                TriggerChip(
                    icon: "xmark.app",
                    label: "Force Close App",
                    color: .orange,
                    isOn: Binding(
                        get: { store.penaltyRules.triggerForceCloseEnabled },
                        set: { store.penaltyRules.triggerForceCloseEnabled = $0 }
                    )
                )
                
                TriggerChip(
                    icon: "arrow.triangle.2.circlepath",
                    label: "Forced Restart",
                    color: .yellow,
                    isOn: Binding(
                        get: { store.penaltyRules.triggerForcedRestartEnabled },
                        set: { store.penaltyRules.triggerForcedRestartEnabled = $0 }
                    )
                )
                
                TriggerChip(
                    icon: "trash",
                    label: "Uninstall & Tamper",
                    color: .purple,
                    isOn: Binding(
                        get: { store.triggerUninstallTamperEnabled },
                        set: { store.triggerUninstallTamperEnabled = $0 }
                    )
                )
                
                // Snooze with threshold
                VStack(spacing: 0) {
                    TriggerChip(
                        icon: "zzz",
                        label: "Excessive Snooze",
                        color: .blue,
                        isOn: Binding(
                            get: { store.triggerSnoozeThresholdEnabled },
                            set: { store.triggerSnoozeThresholdEnabled = $0 }
                        )
                    )
                    
                    if store.triggerSnoozeThresholdEnabled {
                        HStack {
                            Text("Max before penalty")
                                .font(.system(size: 13))
                                .foregroundColor(Colors.textTertiary)
                            
                            Spacer()
                            
                            HStack(spacing: 14) {
                                Button(action: {
                                    if store.snoozePenaltyThreshold > 1 {
                                        store.snoozePenaltyThreshold -= 1
                                    }
                                }) {
                                    Image(systemName: "minus")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(Colors.textSecondary)
                                        .frame(width: 30, height: 30)
                                        .background(Circle().fill(Color.white.opacity(0.06)))
                                }
                                
                                Text("\(store.snoozePenaltyThreshold)")
                                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                    .frame(width: 24)
                                
                                Button(action: {
                                    if store.snoozePenaltyThreshold < 10 {
                                        store.snoozePenaltyThreshold += 1
                                    }
                                }) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.black)
                                        .frame(width: 30, height: 30)
                                        .background(Circle().fill(Colors.accentTeal))
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(red: 0.07, green: 0.08, blue: 0.1))
                        .cornerRadius(14)
                        .padding(.top, 8)
                    }
                }
            }
        }
    }
    
    // MARK: - Violation Row
    
    private var violationRow: some View {
        Button(action: { showViolationCenter = true }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.1))
                        .frame(width: 36, height: 36)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(.red.opacity(0.8))
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("Violation History")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    
                    let pendingCount = store.violations.filter({ $0.status == .pendingGracePeriod }).count
                    let totalCount = store.violations.count
                    Text(pendingCount > 0 ? "\(pendingCount) pending • \(totalCount) total" : "\(totalCount) total")
                        .font(.system(size: 13))
                        .foregroundColor(pendingCount > 0 ? .orange : Colors.textTertiary)
                }
                
                Spacer()
                
                let pendingCount = store.violations.filter({ $0.status == .pendingGracePeriod }).count
                if pendingCount > 0 {
                    Text("\(pendingCount)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.red))
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.25))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.07, green: 0.08, blue: 0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.04), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Trigger Chip

struct TriggerChip: View {
    let icon: String
    let label: String
    let color: Color
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isOn ? color : Color.gray.opacity(0.4))
                .frame(width: 20)
            
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isOn ? .white : Colors.textTertiary)
                .lineLimit(1)
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: color))
                .scaleEffect(0.75)
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isOn ? color.opacity(0.06) : Color(red: 0.07, green: 0.08, blue: 0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isOn ? color.opacity(0.15) : Color.white.opacity(0.03), lineWidth: 1)
        )
    }
}

// MARK: - Penalty Edit Sheet

struct PenaltyEditSheet: View {
    @ObservedObject var store = SettingsStore.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedAmount: Int
    @State private var selectedCurrency: PenaltyCurrency
    @State private var showAddCard = false
    
    init() {
        let s = SettingsStore.shared
        _selectedAmount = State(initialValue: s.penaltyAmountEuro)
        _selectedCurrency = State(initialValue: s.penaltyCurrency)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Colors.bgSecondary, Colors.bgPrimary],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    
                    // Live preview
                    VStack(spacing: 6) {
                        Text("YOUR STAKE")
                            .font(.system(size: 11, weight: .heavy, design: .monospaced))
                            .kerning(3)
                            .foregroundColor(Colors.textTertiary)
                        
                        HStack(alignment: .firstTextBaseline, spacing: 0) {
                            Text(selectedCurrency.symbol)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(Colors.accentTeal)
                            Text("\(selectedAmount)")
                                .font(.system(size: 56, weight: .heavy))
                                .foregroundColor(.white)
                            Text(".00")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(Color.white.opacity(0.3))
                        }
                        .contentTransition(.numericText())
                        
                        Text("charged per violation")
                            .font(.system(size: 14))
                            .foregroundColor(Colors.textTertiary)
                    }
                    .padding(.top, 32)
                    .padding(.bottom, 36)
                    
                    // Currency row
                    HStack(spacing: 6) {
                        ForEach(PenaltyCurrency.allCases, id: \.self) { currency in
                            Button(action: { withAnimation { selectedCurrency = currency } }) {
                                Text(currency.symbol)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(selectedCurrency == currency ? .black : Colors.textSecondary)
                                    .frame(width: 48, height: 40)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(selectedCurrency == currency ? Colors.accentTeal : Color.white.opacity(0.04))
                                    )
                            }
                        }
                    }
                    .padding(.bottom, 28)
                    
                    // Amount scroll selector
                    VStack(alignment: .leading, spacing: 10) {
                        Text("AMOUNT")
                            .font(.system(size: 11, weight: .heavy, design: .monospaced))
                            .kerning(2)
                            .foregroundColor(Colors.textTertiary)
                            .padding(.leading, 20)
                        
                        HStack(spacing: 4) {
                            ForEach(1...10, id: \.self) { amount in
                                Button(action: {
                                    withAnimation(.spring(response: 0.3)) { selectedAmount = amount }
                                }) {
                                    VStack(spacing: 4) {
                                        Text("\(selectedCurrency.symbol)\(amount)")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(selectedAmount == amount ? .black : .white)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.7)
                                        
                                        if selectedAmount == amount {
                                            Circle()
                                                .fill(Color.black.opacity(0.3))
                                                .frame(width: 4, height: 4)
                                        } else {
                                            // Invisible placeholder to keep text aligned
                                            Circle()
                                                .fill(Color.clear)
                                                .frame(width: 4, height: 4)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(selectedAmount == amount ? Colors.accentTeal : Color.white.opacity(0.04))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(selectedAmount == amount ? Colors.accentTeal.opacity(0.5) : Color.white.opacity(0.04), lineWidth: 1)
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // MARK: - Payment Method Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("PAYMENT METHOD")
                            .font(.system(size: 11, weight: .heavy, design: .monospaced))
                            .kerning(2)
                            .foregroundColor(Colors.textTertiary)
                            .padding(.leading, 20)
                        
                        Button(action: { showAddCard = true }) {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(
                                            store.hasValidPenaltyPaymentMethod
                                                ? Colors.accentTeal.opacity(0.12)
                                                : Color.orange.opacity(0.12)
                                        )
                                        .frame(width: 42, height: 30)
                                    Image(systemName: "creditcard.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(
                                            store.hasValidPenaltyPaymentMethod
                                                ? Colors.accentTeal
                                                : .orange
                                        )
                                }
                                
                                if store.hasValidPenaltyPaymentMethod {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(store.penaltyCardBrand.isEmpty ? "Card" : store.penaltyCardBrand.capitalized)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.white)
                                        Text("•••• \(store.penaltyCardLast4.isEmpty ? "••••" : store.penaltyCardLast4)")
                                            .font(.system(size: 13, design: .monospaced))
                                            .foregroundColor(Colors.textTertiary)
                                    }
                                } else {
                                    Text("Attach payment method")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.orange)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Color.white.opacity(0.25))
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white.opacity(0.04))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        store.hasValidPenaltyPaymentMethod
                                            ? Color.white.opacity(0.04)
                                            : Color.orange.opacity(0.2),
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                        
                        if !store.hasValidPenaltyPaymentMethod {
                            Text("A payment method is required to activate penalties.")
                                .font(.system(size: 12))
                                .foregroundColor(.orange.opacity(0.7))
                                .padding(.horizontal, 24)
                        }
                    }
                    .padding(.top, 8)
                    
                    Spacer()
                    
                    // Save
                    Button(action: {
                        store.penaltyAmountEuro = selectedAmount
                        store.penaltyCurrency = selectedCurrency
                        dismiss()
                    }) {
                        Text("Save")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Colors.accentTeal)
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Colors.textSecondary)
                    }
                }
            }
            .sheet(isPresented: $showAddCard) {
                AddPaymentCardView(
                    cardBrand: Binding(
                        get: { store.penaltyCardBrand },
                        set: { store.penaltyCardBrand = $0 }
                    ),
                    cardLast4: Binding(
                        get: { store.penaltyCardLast4 },
                        set: { store.penaltyCardLast4 = $0 }
                    )
                )
            }
        }
    }
}

// MARK: - Add Payment Card View

struct AddPaymentCardView: View {
    @Binding var cardBrand: String
    @Binding var cardLast4: String
    @Environment(\.dismiss) var dismiss
    
    @State private var cardNumber: String = ""
    @State private var expiryDate: String = ""
    @State private var selectedBrand: String = "Visa"
    @State private var animateCard = false
    @State private var showUnavailableAlert = false
    
    private let brands = ["Visa", "Mastercard", "Amex"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Colors.bgSecondary, Colors.bgPrimary],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 28) {
                    // Card Visual
                    ZStack {
                        // Card body
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.08, green: 0.1, blue: 0.14),
                                        Color(red: 0.04, green: 0.05, blue: 0.08)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: 200)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(
                                        LinearGradient(
                                            colors: [Colors.accentTeal.opacity(0.3), Colors.accentTeal.opacity(0.05)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .shadow(color: Colors.accentTeal.opacity(animateCard ? 0.15 : 0.05), radius: 30, x: 0, y: 15)
                        
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                // Chip
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(red: 0.75, green: 0.65, blue: 0.45), Color(red: 0.6, green: 0.5, blue: 0.35)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(width: 36, height: 26)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                                    )
                                
                                Spacer()
                                
                                Text(selectedBrand.uppercased())
                                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                                    .kerning(2)
                                    .foregroundColor(Colors.accentTeal.opacity(0.7))
                            }
                            
                            Spacer()
                            
                            Text(formattedDisplay)
                                .font(.system(size: 20, weight: .medium, design: .monospaced))
                                .kerning(3)
                                .foregroundColor(.white.opacity(0.8))
                            
                            Spacer()
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("CARDHOLDER")
                                        .font(.system(size: 8, weight: .medium))
                                        .foregroundColor(Colors.textTertiary)
                                    Text("ALARMO USER")
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                        .foregroundColor(Colors.textSecondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("EXPIRES")
                                        .font(.system(size: 8, weight: .medium))
                                        .foregroundColor(Colors.textTertiary)
                                    Text(expiryDate.isEmpty ? "MM/YY" : expiryDate)
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                        .foregroundColor(Colors.textSecondary)
                                }
                            }
                        }
                        .padding(24)
                    }
                    .padding(.horizontal, 20)
                    .rotation3DEffect(.degrees(animateCard ? 0 : 5), axis: (x: 1, y: 0, z: 0))
                    
                    // Brand pills
                    HStack(spacing: 8) {
                        ForEach(brands, id: \.self) { brand in
                            Button(action: { selectedBrand = brand }) {
                                Text(brand)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(selectedBrand == brand ? .black : Colors.textSecondary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule().fill(selectedBrand == brand ? Colors.accentTeal : Color.white.opacity(0.04))
                                    )
                            }
                        }
                    }
                    
                    // Fields
                    VStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("LAST 4 DIGITS")
                                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                .kerning(1.5)
                                .foregroundColor(Colors.textTertiary)
                            
                            TextField("", text: $cardNumber, prompt: Text("0000").foregroundColor(Color.white.opacity(0.12)))
                                .font(.system(size: 28, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white)
                                .keyboardType(.numberPad)
                                .padding(16)
                                .background(Color.white.opacity(0.03))
                                .cornerRadius(14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(cardNumber.count == 4 ? Colors.accentTeal.opacity(0.3) : Color.white.opacity(0.04), lineWidth: 1)
                                )
                                .onChange(of: cardNumber) { _, newValue in
                                    cardNumber = String(newValue.filter(\.isNumber).prefix(4))
                                }
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("EXPIRY")
                                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                .kerning(1.5)
                                .foregroundColor(Colors.textTertiary)
                            
                            TextField("", text: $expiryDate, prompt: Text("MM/YY").foregroundColor(Color.white.opacity(0.12)))
                                .font(.system(size: 28, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white)
                                .keyboardType(.numberPad)
                                .padding(16)
                                .background(Color.white.opacity(0.03))
                                .cornerRadius(14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.white.opacity(0.04), lineWidth: 1)
                                )
                                .onChange(of: expiryDate) { _, newValue in
                                    let digits = newValue.filter(\.isNumber)
                                    if digits.count <= 2 {
                                        expiryDate = digits
                                    } else {
                                        let month = String(digits.prefix(2))
                                        let year = String(digits.dropFirst(2).prefix(2))
                                        expiryDate = "\(month)/\(year)"
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    // Attach
                    Button(action: {
                        showUnavailableAlert = true
                    }) {
                        Text("Attach Card")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(cardNumber.count < 4 ? Colors.textTertiary : .black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                Capsule()
                                    .fill(cardNumber.count < 4 ? Color.white.opacity(0.04) : Colors.accentTeal)
                            )
                    }
                    .disabled(cardNumber.count < 4)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Colors.textSecondary)
                    }
                }
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.8)) {
                    animateCard = true
                }
            }
            .alert("Card Setup Unavailable", isPresented: $showUnavailableAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Card processing is not enabled in this build. Use penalty credits from App Store packs.")
            }
        }
    }
    
    private var formattedDisplay: String {
        let last4 = cardNumber.isEmpty ? "••••" : String(cardNumber.suffix(4))
        return "•••• •••• •••• \(last4)"
    }
}

// MARK: - Supporting Views

struct ShieldTile: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Colors.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(Colors.textSecondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: Colors.accentTeal))
        }
        .padding(16)
        .background(Colors.cardSurface)
        .cornerRadius(16)
    }
}

struct InfoRow: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Colors.textSecondary)
                .frame(width: 4, height: 4)
                .padding(.top, 6)
            Text(text)
                .font(.caption)
                .foregroundColor(Colors.textSecondary)
                .lineSpacing(4)
        }
    }
}

#Preview {
    AccountabilityShieldSettingsView()
}
