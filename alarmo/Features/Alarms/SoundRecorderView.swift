import SwiftUI

struct SoundRecorderView: View {
    @Binding var isPresented: Bool
    var onSave: () -> Void
    
    @StateObject private var service = CustomSoundService()
    @State private var soundName: String = ""
    @State private var isRecording = false
    @State private var hasRecorded = false
    @State private var showPermissionError = false
    
    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            
            VStack(spacing: 32) {
                // Header
                Text("Record Custom Sound")
                    .font(.headline)
                    .foregroundColor(Colors.textPrimary)
                    .padding(.top, 20)
                
                Spacer()
                
                // Visualization / Timer
                VStack(spacing: 16) {
                    Text(timeString(from: service.recordingTime))
                        .font(.system(size: 64, weight: .light).monospacedDigit())
                        .foregroundColor(isRecording ? Colors.accentRed : Colors.textPrimary)
                    
                    if isRecording {
                        HStack(spacing: 4) {
                            ForEach(0..<5) { _ in
                                Circle()
                                    .fill(Colors.accentRed)
                                    .frame(width: 8, height: 8)
                                    .opacity(Double.random(in: 0.3...1.0))
                            }
                        }
                    } else if hasRecorded {
                        Text("Recorded successfully")
                            .foregroundColor(Colors.accentGreen)
                    }
                }
                
                Spacer()
                
                // Name Input
                if hasRecorded {
                    VStack(alignment: .leading) {
                        Text("Sound Name")
                            .font(.caption)
                            .foregroundColor(Colors.textSecondary)
                        
                        TextField("Enter name", text: $soundName)
                            .padding()
                            .background(Colors.cardSurface)
                            .cornerRadius(12)
                            .foregroundColor(Colors.textPrimary)
                    }
                    .padding(.horizontal)
                }
                
                // Controls
                if !hasRecorded {
                    Button(action: {
                        if isRecording {
                            service.stopRecording()
                            isRecording = false
                            hasRecorded = true
                        } else {
                            Task {
                                if await service.checkPermission() {
                                    startRecording()
                                } else {
                                    showPermissionError = true
                                }
                            }
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(isRecording ? Colors.accentRed.opacity(0.2) : Colors.cardSurface)
                                .frame(width: 80, height: 80)
                            
                            Circle()
                                .fill(isRecording ? Colors.accentRed : Colors.textPrimary)
                                .frame(width: isRecording ? 30 : 60, height: isRecording ? 30 : 60)
                                .cornerRadius(isRecording ? 4 : 30) // Square when recording
                        }
                    }
                } else {
                    HStack(spacing: 20) {
                        Button("Retake") {
                            soundName = ""
                            hasRecorded = false
                            // cleanup?
                        }
                        .foregroundColor(Colors.textSecondary)
                        
                        PrimaryButton(title: "Save") {
                            guard !soundName.isEmpty else { return }
                            saveRecording(name: soundName)
                            onSave()
                            isPresented = false
                        }
                        .disabled(soundName.isEmpty)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 30)
        }
        .alert("Microphone Permission Required", isPresented: $showPermissionError) {
            Button("Settings", role: .cancel) {
                // Open Settings
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        }
    }
    
    private func startRecording() {
        do {
            // Use soundName if set, otherwise temp. 
            // In this flow we ask for name after. 
            // So we record to a temp name.
            // let tempName = "Recording_\(Int(Date().timeIntervalSince1970))"
            // We need to pass this name out or rename it later. 
            // Saving "soundName" to a state to use during Save?
            // Actually, `startRecording` commits to a filename. 
            // I'll update the logic:
            // 1. Record to UUID.
            // 2. On Save, rename UUID file to `soundName`.
            // Since I can't easily edit Service right now without context switch, 
            // I'll just Ask for Name FIRST? 
            // No, that's bad UX.
            
            // I'll just use the temp name for now and maybe later implement renaming.
            // Wait, the user prompt says "record... and save the sound". 
            // I'll ask for name AFTER on the sheet, and if I can't rename in service easily, 
            // I'll just copy it manually here? 
            // `CustomSoundService` saves to `Docs/CustomSounds/Name.m4a`.
            
            // I'll just modify the logic: Always record to "temp.m4a". 
            // On "Save", copy "temp.m4a" to "UserGivenName.m4a".
            try service.startRecording(name: "temp_recording")
            isRecording = true
        } catch {
            print("Failed to start recording: \(error)")
        }
    }
    
    // Rename logic helper
    func saveRecording(name: String) {
        let fileManager = FileManager.default
        guard let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let source = documents.appendingPathComponent("CustomSounds/temp_recording.m4a")
        let destination = documents.appendingPathComponent("CustomSounds/\(name).m4a")
        
        try? fileManager.moveItem(at: source, to: destination)
    }
    
    func timeString(from interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
