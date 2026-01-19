import Foundation
import AVFoundation
import Combine
import MediaPlayer

class CustomSoundService: NSObject, ObservableObject {
    private var audioRecorder: AVAudioRecorder?
    private let fileManager = FileManager.default
    
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
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
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let customSoundsDir = documents.appendingPathComponent("CustomSounds")
        if !fileManager.fileExists(atPath: customSoundsDir.path) {
            try fileManager.createDirectory(at: customSoundsDir, withIntermediateDirectories: true)
        }
        
        let fileURL = customSoundsDir.appendingPathComponent("\(name).m4a")
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default)
        try session.setActive(true)
        
        audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
        audioRecorder?.record()
        
        DispatchQueue.main.async {
            self.isRecording = true
            self.recordingTime = 0
            self.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                self.recordingTime += 0.1
            }
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        
        DispatchQueue.main.async {
            self.isRecording = false
            self.timer?.invalidate()
            self.timer = nil
        }
        
        try? AVAudioSession.sharedInstance().setActive(false)
    }
    
    func saveImportedFile(from url: URL, name: String) throws {
         let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
         let customSoundsDir = documents.appendingPathComponent("CustomSounds")
         if !fileManager.fileExists(atPath: customSoundsDir.path) {
             try fileManager.createDirectory(at: customSoundsDir, withIntermediateDirectories: true)
         }
         
         let destinationURL = customSoundsDir.appendingPathComponent("\(name).m4a")
         
         if fileManager.fileExists(atPath: destinationURL.path) {
             try fileManager.removeItem(at: destinationURL)
         }
         
         if url.scheme == "ipod-library" {
             // Export from Media Library
             let asset = AVAsset(url: url)
             guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
                 throw NSError(domain: "CustomSoundService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"])
             }
             
             exportSession.outputURL = destinationURL
             exportSession.outputFileType = .m4a
             
             let semaphore = DispatchSemaphore(value: 0)
             var exportError: Error?
             
             exportSession.exportAsynchronously {
                 if let error = exportSession.error {
                     exportError = error
                 }
                 semaphore.signal()
             }
             
             semaphore.wait()
             
             if let error = exportError {
                 throw error
             }
         } else {
             // Standard copy (Files app)
             try fileManager.copyItem(at: url, to: destinationURL)
         }
    }
}
