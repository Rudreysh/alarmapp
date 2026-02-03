import SwiftUI

struct MissionRunnerView: View {
    let mission: MissionRequirement
    let onComplete: () -> Void
    let onCancel: () -> Void
    
    @State private var isSimulatingCam: Bool = false
    @State private var stepsCount: Int = 0
    
    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            
            VStack(spacing: 32) {
                // Header
                HStack {
                    Button("Cancel", action: onCancel)
                        .foregroundColor(Colors.textSecondary)
                    Spacer()
                }
                .padding()
                
                Spacer()
                
                // Mission Content
                if mission.type == "qr" {
                    qrView
                } else if mission.type == "steps" {
                    stepsView
                } else if mission.type == "math" {
                    mathView
                } else {
                    Text("Unknown Mission")
                        .foregroundColor(.white)
                }
                
                Spacer()
            }
        }
    }
    
    var qrView: some View {
        VStack(spacing: 20) {
            Text("Scan QR/Barcode")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Colors.textPrimary)
            
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black)
                    .frame(height: 300)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Colors.cardStroke, lineWidth: 2)
                    )
                
                if isSimulatingCam {
                    ProgressView()
                } else {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                }
                
                // Overlay scanning line animation could go here
                Rectangle()
                    .fill(Colors.accentRed)
                    .frame(height: 2)
                    .padding(.horizontal, 40)
            }
            .padding(.horizontal)
            
            Text(mission.targetValue != nil ? "Scan expected code" : "Scan any code")
                .foregroundColor(Colors.textSecondary)
            
            Button(action: {
                // Simulate success
                onComplete()
            }) {
                Text("Simulate Scan Success")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Colors.accentGreen)
                    .cornerRadius(12)
            }
        }
    }
    
    var stepsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "figure.walk")
                .font(.system(size: 60))
                .foregroundColor(Colors.accentOrange)
            
            Text("Walk \(mission.targetValue ?? "20") Steps")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Colors.textPrimary)
            
            Text("\(stepsCount) / \(mission.targetValue ?? "20")")
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(Colors.textPrimary)
            
            Button(action: {
                let target = Int(mission.targetValue ?? "20") ?? 20
                if stepsCount < target {
                    stepsCount += 5
                }
                if stepsCount >= target {
                    // Delay slightly then complete
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        onComplete()
                    }
                }
            }) {
                Text("Simulate Step")
                    .font(.headline)
                    .foregroundColor(Colors.bgPrimary)
                    .padding()
                    .background(Colors.textPrimary)
                    .cornerRadius(12)
            }
        }
    }
    
    @State private var mathAnswer: String = ""
    var mathView: some View {
        VStack(spacing: 20) {
            Text("Solve this")
                .font(.title2)
                .foregroundColor(Colors.textPrimary)
            
            Text("15 + 27 = ?")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(Colors.textPrimary)
            
            TextField("Answer", text: $mathAnswer)
                .keyboardType(.numberPad)
                .padding()
                .background(Colors.cardSurface)
                .cornerRadius(12)
                .foregroundColor(Colors.textPrimary)
                .frame(width: 150)
            
            Button(action: {
                if mathAnswer == "42" {
                    onComplete()
                }
            }) {
                Text("Submit")
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding()
                    .background(Colors.accentBlue)
                    .cornerRadius(12)
            }
        }
    }
}
