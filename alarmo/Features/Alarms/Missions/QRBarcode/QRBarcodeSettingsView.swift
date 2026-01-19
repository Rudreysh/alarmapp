import SwiftUI

struct QRBarcodeSettingsView: View {
    @StateObject private var viewModel = QRBarcodeMissionViewModel()
    @State private var previewTargetCode: PreviewItem?
    @State private var showNoCodeAlert = false 
    var onSave: (QRBarcodeMissionConfig) -> Void
    @Environment(\.dismiss) var dismiss
    
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
                                    .foregroundColor(.white.opacity(0.8))
                            )
                        
                        Spacer()
                        
                        Button(action: {
                            viewModel.startAdding()
                        }) {
                            Text("Scan")
                                .font(.title3.bold())
                                .foregroundColor(Colors.bgPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(Color.white)
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
                        if let selected = viewModel.missionConfig.selectedRawValueFallback {
                            print("PREVIEW tapped. Selected: \(selected)")
                            previewTargetCode = PreviewItem(code: selected)
                        } else {
                            print("PREVIEW tapped but no code selected.")
                            showNoCodeAlert = true
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.error)
                        }
                    }) {
                        Text("Preview")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(Colors.textPrimary) // Always highlighted
                            .padding(.vertical, Spacing.m)
                            .padding(.horizontal, 24)
                            .background(Colors.cardSurface)
                            .cornerRadius(Radii.button)
                    }
                    
                    PrimaryButton(title: "Done") {
                        onSave(viewModel.missionConfig)
                        dismiss()
                    }
                }
                .padding()
                .background(Colors.bgPrimary)
                .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 0) } 
            }
        }
        .alert(isPresented: $showNoCodeAlert) {
            Alert(
                title: Text("No Barcode Selected"),
                message: Text("Please scan and select a barcode first to preview the mission."),
                dismissButton: .default(Text("OK"))
            )
        }
        .fullScreenCover(item: $previewTargetCode) { item in
             QRBarcodeMissionView(targetCode: item.code, onSuccess: {
                 previewTargetCode = nil
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
                    viewModel.saveBarcode(code, name: viewModel.tempDraftName)
                }
                viewModel.showingNameSheet = false
            }
        }
        .onAppear {
            // Load initial config if needed, usually passed in logic would populate VM
            // Here assuming clean start or VM persists its own simple state
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
