import Foundation
import Combine
import SwiftUI

class QRBarcodeMissionViewModel: ObservableObject {
    @Published var savedBarcodes: [BarcodeRecord] = []
    @Published var missionConfig: QRBarcodeMissionConfig = QRBarcodeMissionConfig()
    @Published var scannerService: BarcodeScannerService = BarcodeScannerService()
    
    // UI States
    @Published var isScanning = false
    @Published var showingNameSheet = false
    @Published var newScannedCode: String?
    @Published var editingRecord: BarcodeRecord? // For renaming if needed
    @Published var tempDraftName = ""
    
    // Runtime States
    @Published var isRuntime = false
    @Published var runtimeTargetCodeVal: String?
    @Published var runtimeFeedbackMessage: String?
    @Published var runtimeIsSuccess = false
    @Published var runtimeIsError = false
    
    private var cancellables = Set<AnyCancellable>()
    private let storageKey = "alarmo_saved_barcodes"
    
    // Callback for mission completion
    var onMissionCompleted: (() -> Void)?
    
    init() {
        loadBarcodes()
        
        // Subscription to scanner
        scannerService.$scannedCode
            .compactMap { $0 }
            .throttle(for: .seconds(1), scheduler: RunLoop.main, latest: false) // Debounce
            .sink { [weak self] codeVal, type in
                self?.handleScan(code: codeVal, type: type)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Core Logic
    
    private func handleScan(code: String, type: String) {
        guard scannerService.isSessionRunning else { return }
        
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if isRuntime {
            // Validate Match
            if let target = runtimeTargetCodeVal, normalized == target {
                // Success
                scannerService.stopSession()
                scannerService.isSessionRunning = false 
                runtimeIsSuccess = true
                runtimeFeedbackMessage = "Good job!"
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.onMissionCompleted?()
                }
            } else {
                // Mismatch
                runtimeIsError = true
                runtimeFeedbackMessage = "Wrong code. Try again."
                // Haptic error
                // In real app use UINotificationFeedbackGenerator
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.runtimeIsError = false
                    self.runtimeFeedbackMessage = nil
                }
            }
        } else {
            // Setup Mode: Capture and ask for save
            scannerService.stopSession() // Pause scanning
            isScanning = false 
            newScannedCode = normalized
            tempDraftName = normalized // Default name
            showingNameSheet = true
        }
    }
    
    // MARK: - Persistence
    
    func loadBarcodes() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let records = try? JSONDecoder().decode([BarcodeRecord].self, from: data) {
            self.savedBarcodes = records
        }
    }
    
    func saveBarcode(_ code: String, name: String) {
        let record = BarcodeRecord(rawValue: code, displayName: name.isEmpty ? code : name)
        savedBarcodes.append(record)
        saveToDisk()
        
        // Select newly added by default if none selected
        if missionConfig.selectedBarcodeId == nil {
            selectBarcode(record)
        }
    }
    
    func deleteBarcode(at offsets: IndexSet) {
        savedBarcodes.remove(atOffsets: offsets)
        saveToDisk()
        // Handle if selected one was deleted
        if let selected = missionConfig.selectedBarcodeId, !savedBarcodes.contains(where: { $0.id == selected }) {
            missionConfig.selectedBarcodeId = nil
            missionConfig.selectedRawValueFallback = nil
        }
    }
    
    private func saveToDisk() {
        if let data = try? JSONEncoder().encode(savedBarcodes) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    // MARK: - Configuration
    
    func selectBarcode(_ record: BarcodeRecord) {
        missionConfig.selectedBarcodeId = record.id
        missionConfig.selectedRawValueFallback = record.rawValue
    }
    
    // MARK: - Actions
    
    func startAdding() {
        isRuntime = false
        // Reset scanner state for fresh scan
        scannerService.scannedCode = nil
        showingNameSheet = false 
        isScanning = true
        scannerService.startSession()
    }
    
    func startRuntimeMission(targetCode: String) {
        isRuntime = true
        runtimeTargetCodeVal = targetCode
    }
    
    func scanForMission() {
        // Ensure runtime mode is active
        isRuntime = true
        scannerService.scannedCode = nil
        isScanning = true
        scannerService.startSession()
    }
}
