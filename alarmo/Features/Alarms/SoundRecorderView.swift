import SwiftUI
import AVFoundation

struct SoundRecorderView: View {
    @Binding var isPresented: Bool
    var onSave: () -> Void
    
    @StateObject private var service = CustomSoundService()
    @State private var soundName: String = ""
    @State private var hasRecorded = false
    @State private var showPermissionError = false
    @State private var validationMessage: String?
    @State private var previewPlayer: AVAudioPlayer?
    @State private var previewDelegate: PreviewDelegate?
    @State private var isPreviewing = false
    @State private var didSave = false
    
    private let maxDuration: TimeInterval = 120
    
    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            
            VStack(spacing: 24) {
                HStack {
                    Spacer()
                    Text("Record Custom Sound")
                        .font(.headline)
                        .foregroundColor(Colors.textPrimary)
                    Spacer()
                }
                .padding(.top, 20)
                
                Spacer()
                
                // Timer + meter
                VStack(spacing: 16) {
                    Text(timeString(from: service.recordingTime))
                        .font(.system(size: 64, weight: .light).monospacedDigit())
                        .foregroundColor(service.isRecording ? Colors.accentRed : Colors.textPrimary)
                    
                    if service.isRecording || service.isPaused {
                        VStack(spacing: 10) {
                            HStack(spacing: 6) {
                                ForEach(0..<20, id: \.self) { idx in
                                    Capsule()
                                        .fill(service.inputLevel > Float(idx) / 20.0 ? Colors.accentBlue : Colors.cardStroke.opacity(0.5))
                                        .frame(width: 5, height: CGFloat(8 + (idx % 6) * 4))
                                }
                            }
                            .animation(.linear(duration: 0.08), value: service.inputLevel)
                            
                            Text(service.isPaused ? "Paused" : "Recording")
                                .font(.caption)
                                .foregroundColor(Colors.textSecondary)
                            Text("Max \(Int(maxDuration))s")
                                .font(.caption2)
                                .foregroundColor(Colors.textSecondary.opacity(0.7))
                        }
                    } else if hasRecorded {
                        Text(isPreviewing ? "Previewing" : "Recorded successfully")
                            .foregroundColor(isPreviewing ? Colors.accentBlue : Colors.accentGreen)
                    }
                    
                    if let validationMessage {
                        Text(validationMessage)
                            .font(.caption)
                            .foregroundColor(Colors.accentRed)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                }
                
                Spacer()
                
                // Name + preview
                if hasRecorded {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Sound Name")
                            .font(.caption)
                            .foregroundColor(Colors.textSecondary)
                        
                        TextField("Enter name", text: $soundName)
                            .padding()
                            .background(Colors.cardSurface)
                            .cornerRadius(12)
                            .foregroundColor(Colors.textPrimary)
                            .onChange(of: soundName) { _, _ in
                                validationMessage = nil
                            }
                        
                        HStack(spacing: 10) {
                            Button(action: {
                                isPreviewing ? stopPreview() : playPreview()
                            }) {
                                Label(isPreviewing ? "Stop Preview" : "Preview", systemImage: isPreviewing ? "stop.fill" : "play.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(Colors.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Colors.cardSurface)
                                    .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Controls
                if !hasRecorded {
                    VStack(spacing: 14) {
                        Button(action: {
                            if service.isRecording || service.isPaused {
                                finalizeRecording()
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
                                    .fill(service.isRecording ? Colors.accentRed.opacity(0.2) : Colors.cardSurface)
                                    .frame(width: 86, height: 86)
                                
                                Circle()
                                    .fill(service.isRecording ? Colors.accentRed : Colors.textPrimary)
                                    .frame(width: service.isRecording ? 32 : 62, height: service.isRecording ? 32 : 62)
                                    .cornerRadius(service.isRecording ? 6 : 31)
                            }
                        }
                        
                        if service.isRecording || service.isPaused {
                            HStack(spacing: 10) {
                                Button(action: {
                                    if service.isPaused {
                                        service.resumeRecording()
                                    } else {
                                        service.pauseRecording()
                                    }
                                }) {
                                    Label(service.isPaused ? "Resume" : "Pause", systemImage: service.isPaused ? "play.fill" : "pause.fill")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(Colors.textPrimary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Colors.cardSurface)
                                        .cornerRadius(12)
                                }
                                
                                Button(action: { finalizeRecording() }) {
                                    Label("Stop", systemImage: "stop.fill")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(Colors.textPrimary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Colors.cardSurface)
                                        .cornerRadius(12)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                } else {
                    HStack(spacing: 20) {
                        Button("Retake") {
                            stopPreview()
                            service.stopRecording()
                            service.removeTemporaryRecording()
                            soundName = ""
                            hasRecorded = false
                            validationMessage = nil
                        }
                        .foregroundColor(Colors.textSecondary)
                        
                        PrimaryButton(title: "Save") {
                            saveRecording()
                        }
                        .disabled(soundName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
        .onChange(of: service.recordingTime) { _, value in
            guard !hasRecorded, service.isRecording else { return }
            if value >= maxDuration {
                validationMessage = "Reached max duration. Recording stopped."
                finalizeRecording()
            }
        }
        .onDisappear {
            stopPreview()
            service.stopRecording()
            if !didSave {
                service.removeTemporaryRecording()
            }
        }
    }
    
    private func startRecording() {
        do {
            try service.startRecording(name: "temp_recording")
            hasRecorded = false
            validationMessage = nil
            didSave = false
        } catch {
            validationMessage = "Failed to start recording: \(error.localizedDescription)"
        }
    }
    
    private func finalizeRecording() {
        service.stopRecording()
        hasRecorded = true
    }
    
    private func playPreview() {
        let url = service.temporaryRecordingURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            stopPreview()
            previewPlayer = try AVAudioPlayer(contentsOf: url)
            let delegate = PreviewDelegate { isPreviewing = false }
            previewDelegate = delegate
            previewPlayer?.delegate = delegate
            previewPlayer?.play()
            isPreviewing = true
        } catch {
            validationMessage = "Preview failed: \(error.localizedDescription)"
        }
    }
    
    private func stopPreview() {
        previewPlayer?.stop()
        previewPlayer = nil
        previewDelegate = nil
        isPreviewing = false
    }
    
    private func saveRecording() {
        let finalName = soundName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !finalName.isEmpty else {
            validationMessage = "Please enter a sound name."
            return
        }
        
        let destination = service.customSoundURL(named: finalName)
        if FileManager.default.fileExists(atPath: destination.path) {
            validationMessage = "A sound with this name already exists."
            return
        }
        
        let fileManager = FileManager.default
        let source = service.temporaryRecordingURL()
        guard fileManager.fileExists(atPath: source.path) else {
            validationMessage = "No recording found to save."
            return
        }
        
        do {
            try fileManager.moveItem(at: source, to: destination)
            didSave = true
            onSave()
            isPresented = false
        } catch {
            validationMessage = "Save failed: \(error.localizedDescription)"
        }
    }
    
    func timeString(from interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

private final class PreviewDelegate: NSObject, AVAudioPlayerDelegate {
    private let onFinish: () -> Void
    
    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish()
    }
}
