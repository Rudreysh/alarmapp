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
    @Published var newScannedSymbology: String?
    @Published var editingRecord: BarcodeRecord? // For renaming if needed
    @Published var tempDraftName = ""
    
    // Runtime States
    @Published var isRuntime = false
    @Published var runtimeTargetCodeVal: String?
    @Published var runtimeFeedbackMessage: String?
    @Published var runtimeIsSuccess = false
    @Published var runtimeIsError = false
    @Published var runtimeTargetSymbology: String?
    
    private var cancellables = Set<AnyCancellable>()
    nonisolated private static let storageKey = "alarmo_saved_barcodes"
    private var runtimeLastMatchedCanonical: String?
    private var runtimeLastMatchedSymbology: String?
    private var runtimeConsecutiveMatches = 0
    private let requiredConsecutiveMatches = 2
    
    // Callback for mission completion
    var onMissionCompleted: (() -> Void)?
    
    init(initialConfig: QRBarcodeMissionConfig = QRBarcodeMissionConfig()) {
        self.missionConfig = initialConfig
        loadBarcodes()
        reconcileSelectionWithSavedBarcodes()
        
        // Subscription to scanner
        scannerService.$scannedCode
            .compactMap { $0 }
            .throttle(for: .milliseconds(250), scheduler: RunLoop.main, latest: true)
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
            guard let target = runtimeTargetCodeVal?.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
            let allowsAnyCode = target.isEmpty || target == "PREVIEW_DUMMY_MODE"
            let scannedCanonical = Self.canonicalCode(normalized)
            let targetCanonical = Self.canonicalCode(target)
            let expectedType = runtimeTargetSymbology
            let typeMatches = expectedType == nil || expectedType == type

            // Validate Match
            if allowsAnyCode || (scannedCanonical == targetCanonical && typeMatches) {
                if runtimeLastMatchedCanonical == scannedCanonical && runtimeLastMatchedSymbology == type {
                    runtimeConsecutiveMatches += 1
                } else {
                    runtimeLastMatchedCanonical = scannedCanonical
                    runtimeLastMatchedSymbology = type
                    runtimeConsecutiveMatches = 1
                }

                guard runtimeConsecutiveMatches >= requiredConsecutiveMatches else {
                    runtimeIsError = false
                    runtimeFeedbackMessage = "Code matched. Hold steady to verify..."
                    return
                }

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
                runtimeConsecutiveMatches = 0
                runtimeLastMatchedCanonical = nil
                runtimeLastMatchedSymbology = nil
                runtimeIsError = true
                if scannedCanonical == targetCanonical && !typeMatches {
                    runtimeFeedbackMessage = "Right value, wrong barcode type. Scan the same \(expectedType ?? "code") format."
                } else {
                    runtimeFeedbackMessage = "Different code detected. Scan the saved target code."
                }
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
            newScannedSymbology = type
            tempDraftName = normalized // Default name
            showingNameSheet = true
        }
    }
    
    // MARK: - Persistence
    
    func loadBarcodes() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let records = try? JSONDecoder().decode([BarcodeRecord].self, from: data) {
            self.savedBarcodes = records
        }
    }
    
    func saveBarcode(_ code: String, name: String, symbology: String?) {
        let record = BarcodeRecord(rawValue: code, displayName: name.isEmpty ? code : name, symbology: symbology)
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
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
    
    // MARK: - Configuration
    
    func selectBarcode(_ record: BarcodeRecord) {
        missionConfig.selectedBarcodeId = record.id
        missionConfig.selectedRawValueFallback = record.rawValue
        missionConfig.selectedSymbologyFallback = record.symbology
    }

    func reconcileSelectionWithSavedBarcodes() {
        if let selectedId = missionConfig.selectedBarcodeId,
           let selectedRecord = savedBarcodes.first(where: { $0.id == selectedId }) {
            missionConfig.selectedRawValueFallback = selectedRecord.rawValue
            missionConfig.selectedSymbologyFallback = selectedRecord.symbology
            return
        }

        if let raw = missionConfig.selectedRawValueFallback,
           let matchedRecord = savedBarcodes.first(where: { $0.rawValue == raw }) {
            missionConfig.selectedBarcodeId = matchedRecord.id
            missionConfig.selectedSymbologyFallback = matchedRecord.symbology
            return
        }

        if missionConfig.selectedBarcodeId == nil,
           missionConfig.selectedRawValueFallback == nil,
           let first = savedBarcodes.first {
            missionConfig.selectedBarcodeId = first.id
            missionConfig.selectedRawValueFallback = first.rawValue
            missionConfig.selectedSymbologyFallback = first.symbology
        }
    }

    nonisolated static func loadSavedBarcodes() -> [BarcodeRecord] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let records = try? JSONDecoder().decode([BarcodeRecord].self, from: data) else {
            return []
        }
        return records
    }

    nonisolated static func rawValue(for barcodeId: UUID) -> String? {
        loadSavedBarcodes().first(where: { $0.id == barcodeId })?.rawValue
    }

    nonisolated static func symbology(for barcodeId: UUID) -> String? {
        loadSavedBarcodes().first(where: { $0.id == barcodeId })?.symbology
    }
    
    // MARK: - Actions
    
    func startAdding() {
        isRuntime = false
        // Reset scanner state for fresh scan
        scannerService.scannedCode = nil
        showingNameSheet = false 
        isScanning = true
        scannerService.setupSession()
        scannerService.startSession()
    }
    
    func startRuntimeMission(targetCode: String, targetSymbology: String? = nil) {
        isRuntime = true
        runtimeTargetCodeVal = targetCode
        runtimeTargetSymbology = targetSymbology
        runtimeConsecutiveMatches = 0
        runtimeLastMatchedCanonical = nil
        runtimeLastMatchedSymbology = nil
        runtimeFeedbackMessage = nil
        runtimeIsError = false
        runtimeIsSuccess = false
    }
    
    func scanForMission() {
        // Ensure runtime mode is active
        isRuntime = true
        scannerService.scannedCode = nil
        runtimeConsecutiveMatches = 0
        runtimeLastMatchedCanonical = nil
        runtimeLastMatchedSymbology = nil
        isScanning = true
        scannerService.setupSession()
        scannerService.startSession()
    }

    private static func canonicalCode(_ code: String) -> String {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        let digitsAndSeparators = CharacterSet.decimalDigits.union(CharacterSet(charactersIn: " -"))
        if trimmed.unicodeScalars.allSatisfy({ digitsAndSeparators.contains($0) }) {
            let digits = trimmed.unicodeScalars.filter { CharacterSet.decimalDigits.contains($0) }
            return String(String.UnicodeScalarView(digits))
        }
        return trimmed.lowercased()
    }
}
