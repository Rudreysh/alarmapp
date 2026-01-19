import SwiftUI

struct PreventPowerOffView: View {
    @ObservedObject var store = SettingsStore.shared
    @Environment(\.dismiss) var dismiss
    @State private var showConnectApple = false
    
    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .padding(20)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Self penalty")
                                .font(.system(size: 28, weight: .bold))
                            Text("for my cheating self")
                                .font(.system(size: 28, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        
                        HStack {
                            Text("Those on the challenge")
                                .font(.system(size: 14))
                                .foregroundColor(Colors.textSecondary)
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: "bolt.fill")
                                    .foregroundColor(.yellow)
                                Text("5.911")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Penalty Card
                        SettingsCard {
                            VStack(alignment: .leading, spacing: 20) {
                                Text("Penalty")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text("$\(Double(store.perCheatAmountCents)/100, specifier: "%.2f") per cheat")
                                    .font(.system(size: 34, weight: .black))
                                    .foregroundColor(.white)
                                
                                HStack(spacing: 12) {
                                    Image(systemName: "creditcard.fill")
                                        .foregroundColor(Colors.textSecondary)
                                    Text(store.isPenaltyPaymentConnected ? "Card registered" : "No card registered")
                                        .font(.system(size: 15))
                                        .foregroundColor(Colors.textSecondary)
                                }
                                
                                Button(action: { showConnectApple = true }) {
                                    Text("Set penalty")
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundColor(.black)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(Color.white)
                                        .cornerRadius(12)
                                }
                            }
                            .padding(20)
                        }
                        
                        // History Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Detection history")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                            
                            if store.cheatEvents.isEmpty {
                                VStack(spacing: 12) {
                                    Text("Clear for now")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(Colors.textSecondary)
                                    Text("Penalty records will appear here")
                                        .font(.system(size: 15))
                                        .foregroundColor(Colors.textTertiary)
                                    
                                    Image(systemName: "doc.text.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(Color.white.opacity(0.1))
                                        .padding(.top, 20)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                            } else {
                                // List history
                                VStack(spacing: 0) {
                                    ForEach(store.penaltyRecords.reversed()) { record in
                                        HStack {
                                            VStack(alignment: .leading) {
                                                Text("Cheat detected")
                                                    .font(.system(size: 16, weight: .bold))
                                                    .foregroundColor(.white)
                                                Text(formattedDate(record.date))
                                                    .font(.system(size: 13))
                                                    .foregroundColor(Colors.textSecondary)
                                            }
                                            Spacer()
                                            Text("-$\(Double(record.amountCents)/100, specifier: "%.2f")")
                                                .font(.system(size: 17, weight: .bold))
                                                .foregroundColor(.red)
                                        }
                                        .padding()
                                        Divider().background(Color.white.opacity(0.1))
                                    }
                                }
                                .background(Colors.cardSurface)
                                .cornerRadius(12)
                                .padding(.horizontal, 20)
                            }
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .fullScreenCover(isPresented: $showConnectApple) {
            PenaltyConnectView()
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, HH:mm"
        return formatter.string(from: date)
    }
}

struct PenaltyConnectView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var store = SettingsStore.shared
    
    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            
            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .padding(20)
                
                Spacer()
                
                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: "icloud.and.arrow.up.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                    }
                    
                    Text("Keep your record safe\nby signing in")
                        .font(.system(size: 24, weight: .bold))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                VStack(spacing: 20) {
                    Button(action: {
                        // Simulate Apple Pay connection / Payment setup
                        store.isPenaltyPaymentConnected = true
                        store.preventPowerOffEnabled = true
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "applelogo")
                            Text("Continue with Apple")
                        }
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white)
                        .cornerRadius(28)
                    }
                    .padding(.horizontal, 40)
                    
                    Text("By proceeding, you are agreeing to our [Terms & Conditions](https://example.com) and [Privacy Policy](https://example.com).")
                        .font(.system(size: 11))
                        .foregroundColor(Colors.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(.bottom, 40)
            }
        }
    }
}
