import SwiftUI

struct QuickAlarmTimePickerView: View {
    @Binding var minutes: Int
    @Binding var seconds: Int
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            // Dark background matching the app theme
            Color(red: 0.06, green: 0.07, blue: 0.10)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header (Cancel, Title, Save)
                HStack(alignment: .center) {
                    Button(action: { dismiss() }) {
                        Text("Cancel")
                            .foregroundColor(Colors.textSecondary)
                    }
                    .frame(width: 80, alignment: .leading)
                    
                    Spacer()
                    
                    Text("Quick Alarm")
                        .font(.headline)
                        .foregroundColor(Colors.textPrimary)
                    
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        Text("Save")
                            .foregroundColor(Colors.accentTeal)
                    }
                    .frame(width: 80, alignment: .trailing)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                
                Spacer()
                
                // Wheel Picker Area
                ZStack {
                    // Frosted selection bar behind the selected row
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .frame(height: 48)
                    
                    HStack(spacing: 0) {
                        // Minute Picker
                        Picker("Minute", selection: $minutes) {
                            ForEach(0..<100) { m in
                                Text(String(format: "%02d", m))
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundColor(Colors.textPrimary)
                                    .tag(m)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 100)
                        .clipped()
                        
                        Text("m")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(Colors.textPrimary)
                            .offset(y: 2)
                        
                        // Second Picker
                        Picker("Second", selection: $seconds) {
                            ForEach(0..<60) { s in
                                Text(String(format: "%02d", s))
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundColor(Colors.textPrimary)
                                    .tag(s)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 100)
                        .clipped()
                        
                        Text("s")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(Colors.textPrimary)
                            .offset(y: 2)
                    }
                }
                .frame(height: 220)
                .padding(.horizontal, 24)
                
                Spacer()
            }
        }
        .colorScheme(.dark)
        .presentationDetents([.height(340)])
        .presentationDragIndicator(.visible)
    }
}
