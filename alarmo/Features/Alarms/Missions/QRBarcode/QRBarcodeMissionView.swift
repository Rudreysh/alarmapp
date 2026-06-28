import SwiftUI

struct QRBarcodeMissionView: View {
    @StateObject var viewModel: QRBarcodeMissionViewModel
    @Environment(\.dismiss) var dismiss
    
    // Injected callback for when mission is done (managed by parent view usually)
    var onMissionSuccess: (() -> Void)?
    
    // Target code to match
    let targetCode: String
    let targetSymbology: String?
    
    init(
        viewModel: QRBarcodeMissionViewModel? = nil,
        targetCode: String,
        targetSymbology: String? = nil,
        onSuccess: (() -> Void)?
    ) {
        // If VM is passed reuse it (e.g. from coordinator), else create new
        _viewModel = StateObject(wrappedValue: viewModel ?? QRBarcodeMissionViewModel())
        self.targetCode = targetCode
        self.targetSymbology = targetSymbology
        self.onMissionSuccess = onSuccess
    }
    
    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            
            VStack {
                // Top Bar
                HStack {
                    Button(action: { 
                        // Back typically disabled during strict mission, or goes to emergency
                        // For now simple dismiss for testing
                         dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundColor(Colors.textPrimary)
                    }
                    
                    Spacer()
                    
                    // Progress or Title
                    Text("1/1")
                        .font(.headline)
                        .foregroundColor(Colors.textPrimary)
                    
                    Spacer()
                    
                    // Sound Toggle (Mocking functionality as requested logic says "don't stop alarm")
                    Button(action: {
                        // Toggle local sound mute state if implemented
                    }) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.title2)
                            .foregroundColor(Colors.textPrimary)
                    }
                }
                .padding()
                .padding(.top, 40)
                
                Spacer()
                
                // Content
                VStack(spacing: 30) {
                    Image(systemName: "barcode.viewfinder")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .foregroundColor(Colors.textPrimary)

                    Text(targetCode == "PREVIEW_DUMMY_MODE" ? "Scan any code to dismiss" : "Scan this code to dismiss")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Colors.textSecondary)

                    Text(targetCode == "PREVIEW_DUMMY_MODE" ? "Preview (Scan anything)" : targetCode)
                        .font(.system(size: 32, weight: .bold)) // Large text
                        .foregroundColor(Colors.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.5)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    if let targetSymbology, !targetSymbology.isEmpty, targetCode != "PREVIEW_DUMMY_MODE" {
                        Text(targetSymbology.uppercased())
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(Colors.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(MissionTheme.softFill)
                            .cornerRadius(8)
                    }
                }
                
                Spacer()
                
                // Scan Button
                Button(action: {
                    viewModel.scanForMission()
                }) {
                    Text("Scan")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(MissionTheme.primaryButtonGradient)
                        .cornerRadius(16)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            // Use fullScreenCover for Scanner to ensure it goes over everything
            .fullScreenCover(isPresented: $viewModel.isScanning) {
                ZStack {
                    QRScannerView(
                        service: viewModel.scannerService,
                        autoEnableTorch: true,
                        instruction: targetCode == "PREVIEW_DUMMY_MODE"
                            ? "Point the camera at any QR or barcode"
                            : "Point the camera at your saved code to stop the alarm"
                    ) {
                        viewModel.isScanning = false
                        viewModel.scannerService.stopSession()
                    }
                    
                    // Feedback Overlays
                    if let message = viewModel.runtimeFeedbackMessage {
                        VStack {
                            Spacer()
                            Text(message)
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .background(viewModel.runtimeIsError ? Color.red : Colors.accentGreen)
                                .cornerRadius(12)
                                .padding(.bottom, 100)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        .zIndex(2) // Above scanner
                    }
                }
            }
        }
        .onAppear {
            viewModel.startRuntimeMission(targetCode: targetCode, targetSymbology: targetSymbology)
            viewModel.onMissionCompleted = {
                self.onMissionSuccess?()
            }
            // Open the camera immediately (like Alarmy) so the user never has to
            // hunt for a "Scan" button while the alarm is blaring. The manual
            // button remains as a fallback if they cancel out of the scanner.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                if !viewModel.isScanning && !viewModel.runtimeIsSuccess {
                    viewModel.scanForMission()
                }
            }
        }
        .onChange(of: viewModel.isScanning) { _, scanning in
             // Ensure audio keeps playing (Logic handled by Audio Service in real app)
             // Here we ensure view updates don't break flow
        }
    }
}
