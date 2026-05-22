import Foundation
import AVFoundation
import Combine
import MediaPlayer

class CustomSoundService: NSObject, ObservableObject {
    private var audioRecorder: AVAudioRecorder?
    private let fileManager = FileManager.default
    
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var recordingTime: TimeInterval = 0
    @Published var inputLevel: Float = 0
    private var timer: Timer?
    
    override init() {
        super.init()
    }
    
    func checkPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
             if #available(iOS 17.0, *) {
                 AVAudioApplication.requestRecordPermission { granted in
                     continuation.resume(returning: granted)
                 }
             } else {
                 AVAudioSession.sharedInstance().requestRecordPermission { granted in
                     continuation.resume(returning: granted)
                 }
             }
        }
    }
    
    func checkMediaLibraryPermission() async -> Bool {
        let status = MPMediaLibrary.authorizationStatus()
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                MPMediaLibrary.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
    
    func startRecording(name: String) throws {
        let customSoundsDir = try customSoundsDirectoryURL()
        let fileURL = customSoundsDir.appendingPathComponent("\(name).m4a")
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
        
        // Use standard settings for AAC recording
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default)
        try session.setActive(true)
        
        // Use basic init if newer one is not easily available without protocol changes, 
        // or just suppress if we want to keep it simple. But to fix warning:
        // AVAudioRecorder(url:settings:) is NOT deprecated. 
        // The warning was about init(url:) in AVAsset? No. 
        // Let's look at the logs again: "init(url:) was deprecated in iOS 18.0: Use AVURLAsset(url:) instead" in CustomSoundService.swift:110:26
        // That is inside saveImportedFile.
        
        audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
        audioRecorder?.isMeteringEnabled = true
        audioRecorder?.record()
        
        DispatchQueue.main.async {
            self.isRecording = true
            self.isPaused = false
            self.recordingTime = 0
            self.inputLevel = 0
            self.startMeterTimer()
        }
    }

    func pauseRecording() {
        guard let recorder = audioRecorder, recorder.isRecording else { return }
        recorder.pause()
        DispatchQueue.main.async {
            self.isRecording = false
            self.isPaused = true
            self.stopMeterTimer()
        }
    }

    func resumeRecording() {
        guard let recorder = audioRecorder, !recorder.isRecording else { return }
        recorder.record()
        DispatchQueue.main.async {
            self.isRecording = true
            self.isPaused = false
            self.startMeterTimer()
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        
        DispatchQueue.main.async {
            self.isRecording = false
            self.isPaused = false
            self.inputLevel = 0
            self.stopMeterTimer()
        }
        
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    func removeTemporaryRecording() {
        let tempURL = temporaryRecordingURL()
        if fileManager.fileExists(atPath: tempURL.path) {
            try? fileManager.removeItem(at: tempURL)
        }
    }

    func temporaryRecordingURL() -> URL {
        (try? customSoundsDirectoryURL())?.appendingPathComponent("temp_recording.m4a")
        ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CustomSounds/temp_recording.m4a")
    }

    func customSoundURL(named name: String) -> URL {
        let dir = (try? customSoundsDirectoryURL()) ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CustomSounds")
        return dir.appendingPathComponent("\(name).m4a")
    }

    func nextAvailableRecordingName(base: String = "Recording") -> String {
        let dir = (try? customSoundsDirectoryURL()) ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CustomSounds")

        let existingNames: Set<String>
        if let urls = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            existingNames = Set(
                urls
                    .filter { $0.pathExtension.lowercased() == "m4a" }
                    .map { $0.deletingPathExtension().lastPathComponent.lowercased() }
            )
        } else {
            existingNames = []
        }

        var index = 1
        while true {
            let candidate = "\(base) \(index)"
            if !existingNames.contains(candidate.lowercased()) {
                return candidate
            }
            index += 1
        }
    }

    private func customSoundsDirectoryURL() throws -> URL {
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let customSoundsDir = documents.appendingPathComponent("CustomSounds")
        if !fileManager.fileExists(atPath: customSoundsDir.path) {
            try fileManager.createDirectory(at: customSoundsDir, withIntermediateDirectories: true)
        }
        return customSoundsDir
    }

    private func startMeterTimer() {
        stopMeterTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.recordingTime += 0.05
            self.audioRecorder?.updateMeters()
            let avgPower = self.audioRecorder?.averagePower(forChannel: 0) ?? -160
            let normalized = max(0, min(1, (avgPower + 60) / 60))
            self.inputLevel = normalized
        }
    }

    private func stopMeterTimer() {
        timer?.invalidate()
        timer = nil
    }

    func saveImportedFile(from url: URL, name: String) async throws {
         let customSoundsDir = try customSoundsDirectoryURL()
         let destinationURL = customSoundsDir.appendingPathComponent("\(name).m4a")
         
         if fileManager.fileExists(atPath: destinationURL.path) {
             try fileManager.removeItem(at: destinationURL)
         }
         
         if url.scheme == "ipod-library" {
             // Export from Media Library
             let asset = AVURLAsset(url: url)
             guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
                 throw NSError(domain: "CustomSoundService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"])
             }
             
             exportSession.outputURL = destinationURL
             exportSession.outputFileType = .m4a
             
             if #available(iOS 18.0, *) {
                 try await exportSession.export(to: destinationURL, as: .m4a)
             } else {
                 await exportSession.export()
                 if let error = exportSession.error {
                     throw error
                 }
             }
         } else {
             // Standard copy (Files app)
             // Check if we need to coordinate access
             if url.startAccessingSecurityScopedResource() {
                 defer { url.stopAccessingSecurityScopedResource() }
                 try fileManager.copyItem(at: url, to: destinationURL)
             } else {
                 try fileManager.copyItem(at: url, to: destinationURL)
             }
         }
    }

    func renameCustomSound(from sourceURL: URL, to newName: String) throws -> URL {
        let sanitized = sanitizeFilename(newName)
        guard !sanitized.isEmpty else {
            throw NSError(domain: "CustomSoundService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid sound name"])
        }

        let destinationURL = sourceURL
            .deletingLastPathComponent()
            .appendingPathComponent("\(sanitized).\(sourceURL.pathExtension)")

        if sourceURL == destinationURL { return sourceURL }
        if fileManager.fileExists(atPath: destinationURL.path) {
            throw NSError(domain: "CustomSoundService", code: 3, userInfo: [NSLocalizedDescriptionKey: "A sound with this name already exists"])
        }

        try fileManager.moveItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }

    func deleteCustomSound(at url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    private func sanitizeFilename(_ raw: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        let cleaned = raw
            .components(separatedBy: invalid)
            .joined(separator: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned
    }
}
