import SwiftUI

struct ProView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var subManager = SubscriptionManager.shared
    
    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .padding(20)
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.orange.opacity(0.2))
                                    .frame(width: 64, height: 64)
                                Image(systemName: "star.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.orange)
                            }
                            
                            Text("Pro Subscribed")
                                .font(.system(size: 24, weight: .heavy))
                                .foregroundColor(.white)
                            
                            Text("Renews at \(formattedDate(subManager.renewalDate))")
                                .font(.system(size: 14))
                                .foregroundColor(Colors.textSecondary)
                            
                            Text(subManager.planName)
                                .font(.system(size: 14, weight: .bold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(Color.green.opacity(0.2))
                                .foregroundColor(.green)
                                .clipShape(Capsule())
                        }
                        
                        // Alarm Power Card
                        SettingsCard {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundColor(.red)
                                    Text("Strengthen the alarm power!")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.red)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14))
                                        .foregroundColor(.red.opacity(0.6))
                                }
                                
                                HStack(alignment: .bottom, spacing: 8) {
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(.yellow)
                                    Text("30")
                                        .font(.system(size: 40, weight: .black))
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    // Small bar chart illustration
                                    HStack(alignment: .bottom, spacing: 4) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(LinearGradient(colors: [.orange, .red], startPoint: .top, endPoint: .bottom))
                                            .frame(width: 12, height: 15)
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.white.opacity(0.1))
                                            .frame(width: 12, height: 35)
                                    }
                                }
                                
                                Text("lower than average")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .padding(20)
                        }
                        .background(Color.red.opacity(0.05))
                        .cornerRadius(24)
                        
                        // Usage Card
                        SettingsCard {
                            HStack(spacing: 20) {
                                ZStack {
                                    Circle()
                                        .stroke(Color.white.opacity(0.1), lineWidth: 8)
                                        .frame(width: 80, height: 80)
                                    
                                    Circle()
                                        .trim(from: 0, to: 0.1)
                                        .stroke(Color.orange, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                        .frame(width: 80, height: 80)
                                        .rotationEffect(.degrees(-90))
                                    
                                    Text("1/10")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Pro feature usage")
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundColor(.white)
                                    Text("You're missing out\nmany features!")
                                        .font(.system(size: 15))
                                        .foregroundColor(Colors.textSecondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Colors.textTertiary)
                            }
                            .padding(20)
                        }
                        
                        Button(action: {
                            UIApplication.shared.open(subManager.manageSubscriptionsURL)
                        }) {
                            Text("Cancel Subscription")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Colors.textSecondary)
                                .frame(width: 200)
                                .padding(.vertical, 14)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(12)
                        }
                        .padding(.top, 20)
                    }
                    .padding(.bottom, 40)
                }
            }
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }
}
