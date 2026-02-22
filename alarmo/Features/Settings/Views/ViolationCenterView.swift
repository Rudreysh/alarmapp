import SwiftUI

struct ViolationCenterView: View {
    @ObservedObject var store = SettingsStore.shared
    @Environment(\.dismiss) var dismiss
    
    var pendingViolations: [ViolationEvent] {
        store.violations.filter { $0.status == .pendingGracePeriod || $0.status == .pendingReview || $0.status == .paymentFailed }
            .sorted(by: { $0.timestamp > $1.timestamp })
    }
    
    var historyViolations: [ViolationEvent] {
        store.violations.filter { $0.status == .charged || $0.status == .excused }
            .sorted(by: { $0.timestamp > $1.timestamp })
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                SettingsGlassBackground()
                
                if store.violations.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        Text("No Violations")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(Colors.textPrimary)
                        Text("Great job keeping your commitments!")
                            .foregroundColor(Colors.textSecondary)
                    }
                } else {
                    List {
                        if !pendingViolations.isEmpty {
                            Section(header: Text("Action Required").foregroundColor(Colors.textSecondary)) {
                                ForEach(pendingViolations) { violation in
                                    NavigationLink(destination: ExemptionRequestView(violation: violation)) {
                                        ViolationRow(violation: violation)
                                    }
                                }
                            }
                            .listRowBackground(Color.white.opacity(0.05))
                        }
                        
                        if !historyViolations.isEmpty {
                            Section(header: Text("History").foregroundColor(Colors.textSecondary)) {
                                ForEach(historyViolations) { violation in
                                    ViolationRow(violation: violation)
                                }
                            }
                            .listRowBackground(Color.white.opacity(0.05))
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Violation Center")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ViolationRow: View {
    let violation: ViolationEvent
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(violationTitle)
                    .font(.headline)
                    .foregroundColor(Colors.textPrimary)
                Text(violation.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(Colors.textSecondary)
            }
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("€\(violation.chargedAmount)")
                    .fontWeight(.bold)
                    .foregroundColor(amountColor)
                
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(statusColor)
            }
        }
    }
    
    var violationTitle: String {
        switch violation.type {
        case .shutdownAttempt: return "Shutdown Detected"
        case .uninstallTamper: return "Tamper/Uninstall"
        case .snoozeThresholdExceeded: return "Excessive Snooze"
        case .forceClose: return "Force Close"
        case .airplaneModeAbuse: return "Airplane Mode"
        case .forcedRestart: return "Forced Restart"
        case .severeBatteryDrain: return "Battery Failure"
        case .alarmMissionFailed: return "Mission Failed"
        default: return "Violation"
        }
    }
    
    var amountColor: Color {
        if violation.type == .alarmMissionFailed { return .red } // Adjust logic if needed
        if violation.status == .charged { return .red }
        if violation.status == .excused { return .gray }
        return .orange
    }
    
    var statusText: String {
        switch violation.status {
        case .pendingGracePeriod:
            if let expires = violation.gracePeriodExpiresAt {
                let hours = Int(expires.timeIntervalSinceNow / 3600)
                return hours > 0 ? "\(hours)h left" : "Expires soon"
            }
            return "Pending"
        case .pendingReview: return "In Review"
        case .excused: return "Excused"
        case .charged: return "Charged"
        case .paymentFailed: return "Payment Failed"
        }
    }
    
    var statusColor: Color {
        switch violation.status {
        case .pendingGracePeriod: return .orange
        case .pendingReview: return .blue
        case .excused: return .green
        case .charged: return .red
        case .paymentFailed: return .red
        default: return .orange
        }
    }
}

struct ExemptionRequestView: View {
    let violation: ViolationEvent
    @Environment(\.dismiss) var dismiss
    @State private var selectedReason = "Technical Issue"
    @State private var comments = ""
    @State private var showSuccess = false
    
    let reasons = ["Technical Issue", "Emergency", "Accidental", "Other"]
    
    var body: some View {
        ZStack {
            SettingsGlassBackground()
            
            ScrollView {
                VStack(spacing: 24) {
                    SettingsCard {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Violation Details")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            HStack {
                                Text("Type")
                                    .foregroundColor(Colors.textSecondary)
                                Spacer()
                                Text(violationTitle)
                                    .foregroundColor(.white)
                            }
                            HStack {
                                Text("Amount")
                                    .foregroundColor(Colors.textSecondary)
                                Spacer()
                                Text("€\(violation.chargedAmount)")
                                    .foregroundColor(.white)
                            }
                            HStack {
                                Text("Time")
                                    .foregroundColor(Colors.textSecondary)
                                Spacer()
                                Text(violation.timestamp.formatted())
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(16)
                    }
                    
                    SettingsCard {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Request Exemption")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Menu {
                                ForEach(reasons, id: \.self) { reason in
                                    Button(reason) { selectedReason = reason }
                                }
                            } label: {
                                HStack {
                                    Text("Reason")
                                        .foregroundColor(Colors.textSecondary)
                                    Spacer()
                                    Text(selectedReason)
                                        .foregroundColor(.white)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .foregroundColor(Colors.textTertiary)
                                }
                                .padding(16)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(8)
                            }
                            
                            TextField("Additional Comments (Optional)", text: $comments, axis: .vertical)
                                .lineLimit(3...6)
                                .padding(12)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(8)
                                .foregroundColor(.white)
                        }
                        .padding(16)
                    }
                    
                    Button(action: {
                        submitRequest()
                    }) {
                        Text("Submit Request")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Colors.accentBlue)
                            .cornerRadius(16)
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Request Exemption")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Request Submitted", isPresented: $showSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your request has been received. The charge has been put on hold pending review.")
        }
    }
    
    func submitRequest() {
        AccountabilityShieldEngine.shared.requestExemption(
            violationId: violation.id,
            reasonCategory: selectedReason,
            reasonText: comments
        )
        showSuccess = true
    }
    
    var violationTitle: String {
        switch violation.type {
        case .shutdownAttempt: return "Shutdown Detected"
        case .uninstallTamper: return "Tamper/Uninstall"
        case .snoozeThresholdExceeded: return "Excessive Snooze"
        case .forceClose: return "Force Close"
        case .airplaneModeAbuse: return "Airplane Mode"
        case .forcedRestart: return "Forced Restart"
        case .severeBatteryDrain: return "Battery Failure"
        case .alarmMissionFailed: return "Mission Failed"
        default: return "Violation"
        }
    }
}
