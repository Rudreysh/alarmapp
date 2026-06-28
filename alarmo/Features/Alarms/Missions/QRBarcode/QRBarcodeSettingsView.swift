import SwiftUI

struct QRBarcodeSettingsView: View {
    @StateObject private var viewModel: QRBarcodeMissionViewModel
    @State private var previewTargetCode: PreviewItem?
    @State private var showNoCodeAlert = false 
    @State private var showAlarmPreview = false
    @State private var showGamePreview = false
    var onSave: (QRBarcodeMissionConfig) -> Void
    @Environment(\.dismiss) var dismiss

    init(
        initialConfig: QRBarcodeMissionConfig = QRBarcodeMissionConfig(),
        onSave: @escaping (QRBarcodeMissionConfig) -> Void
    ) {
        _viewModel = StateObject(wrappedValue: QRBarcodeMissionViewModel(initialConfig: initialConfig))
        self.onSave = onSave
    }
    
    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Spacer()
                    Text("QR/Barcode")
                        .font(.headline)
                        .foregroundColor(Colors.textPrimary)
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(Colors.textPrimary)
                    }
                }
                .padding()
                
                if viewModel.savedBarcodes.isEmpty {
                    // Landing Screen State
                    VStack(spacing: 32) {
                        Spacer()
                        
                        Text("Scan a code of a part of\nyour morning routine")
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                            .foregroundColor(Colors.textPrimary)
                            .padding(.horizontal)
                        
                        // Placeholder Image Card
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 200, height: 200)
                            .overlay(
                                Image(systemName: "barcode.viewfinder")
                                    .font(.system(size: 80))
                                    .foregroundColor(MissionTheme.backgroundMutedText)
                            )
                        
                        Spacer()
                        
                        Button(action: {
                            viewModel.startAdding()
                        }) {
                            Text("Scan")
                                .font(.title3.bold())
                                .foregroundColor(MissionTheme.secondaryButtonText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(MissionTheme.secondaryButtonFill)
                                .cornerRadius(16)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)
                    }
                } else {
                    // List State
                    VStack(spacing: 0) {
                        // Add Button
                        Button(action: {
                            viewModel.startAdding()
                        }) {
                            Text("+ Add")
                                .font(.headline)
                                .foregroundColor(Colors.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Colors.cardStroke, lineWidth: 1)
                                )
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                        
                        // List
                        ScrollView {
                            VStack(spacing: 12) {
                                ForEach(viewModel.savedBarcodes) { record in
                                    BarcodeRow(
                                        record: record,
                                        isSelected: viewModel.missionConfig.selectedBarcodeId == record.id
                                    ) {
                                        viewModel.selectBarcode(record)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        Spacer()
                    }
                }
                
                // Bottom Buttons
                HStack(spacing: 16) {
                    Button(action: {
                        let selected = viewModel.missionConfig.selectedRawValueFallback ?? "PREVIEW_DUMMY_MODE"
                        previewTargetCode = PreviewItem(code: selected)
                        showAlarmPreview = true
                    }) {
                        Text("Preview")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(MissionTheme.secondaryButtonText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(MissionTheme.secondaryButtonFill)
                            .cornerRadius(32)
                    }
                    
                    Button(action: {
                        guard let selectedCode = viewModel.missionConfig.selectedRawValueFallback?.trimmingCharacters(in: .whitespacesAndNewlines),
                              !selectedCode.isEmpty else {
                            showNoCodeAlert = true
                            return
                        }
                        onSave(viewModel.missionConfig)
                        dismiss()
                    }) {
                        Text("Done")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(MissionTheme.primaryButtonGradient)
                            .cornerRadius(32)
                            .shadow(color: MissionTheme.primaryButtonShadow, radius: 15, x: 0, y: 10)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                .background(Colors.bgPrimary)
                .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 0) } 
            }
        }
        .fullScreenCover(isPresented: $showAlarmPreview) {
            MissionPreviewAlarmView(
                missionTitle: "QR/Barcode",
                missionIcon: "barcode.viewfinder"
            ) {
                showAlarmPreview = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    showGamePreview = true
                }
            }
        }
        .fullScreenCover(isPresented: $showGamePreview) {
             QRBarcodeMissionView(targetCode: previewTargetCode?.code ?? "", onSuccess: {
                 showGamePreview = false
             })
        }
        .fullScreenCover(isPresented: $viewModel.isScanning) {
            QRScannerView(service: viewModel.scannerService) {
                viewModel.isScanning = false
                viewModel.scannerService.stopSession()
            }
        }
        .sheet(isPresented: $viewModel.showingNameSheet) {
            BarcodeNameSheet(
                code: viewModel.newScannedCode ?? "",
                name: $viewModel.tempDraftName
            ) {
                if let code = viewModel.newScannedCode {
                    viewModel.saveBarcode(code, name: viewModel.tempDraftName, symbology: viewModel.newScannedSymbology)
                }
                viewModel.showingNameSheet = false
            }
        }
        .onAppear {
            viewModel.reconcileSelectionWithSavedBarcodes()
        }
        .alert("Scan or select a code first", isPresented: $showNoCodeAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("This mission needs one QR or barcode target.")
        }
    }
}

struct PreviewItem: Identifiable {
    let id = UUID()
    let code: String
}

struct BarcodeRow: View {
    let record: BarcodeRecord
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Radio Dot
                Circle()
                    .strokeBorder(isSelected ? Colors.accentTeal : Colors.textTertiary, lineWidth: 2)
                    .background(Circle().fill(isSelected ? Colors.accentTeal : Color.clear))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .fill(Color.white)
                            .frame(width: 8, height: 8)
                            .opacity(isSelected ? 1 : 0)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.displayName ?? record.rawValue)
                        .font(.body.bold())
                        .foregroundColor(Colors.textPrimary)
                    
                    if record.displayName != nil {
                        Text(record.rawValue)
                            .font(.caption)
                            .foregroundColor(Colors.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                
                Spacer()
                
                Image(systemName: "ellipsis")
                    .foregroundColor(Colors.textSecondary)
            }
            .padding()
            .background(Colors.cardSurface)
            .cornerRadius(12)
        }
    }
}

struct BarcodeNameSheet: View {
    let code: String
    @Binding var name: String
    var onSave: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            
            VStack(spacing: 24) {
                Text("QR/Barcode Name")
                    .font(.headline)
                    .foregroundColor(Colors.textPrimary)
                    .padding(.top, 24)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(code)
                        .font(.caption)
                        .foregroundColor(Colors.textSecondary)
                        .padding(.horizontal)
                    
                    TextField("Name", text: $name)
                        .textFieldStyle(RoundedBorderTextFieldStyle()) // Custom style normally
                        .padding(.horizontal)
                        .colorScheme(.dark)
                }
                
                PrimaryButton(title: "Save") {
                    onSave()
                }
                .padding(.horizontal)
                
                Spacer()
            }
        }
        .presentationDetents([.height(250)])
    }
}
