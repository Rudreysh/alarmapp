import SwiftUI
import AVFoundation

struct QRScannerView: View {
    @ObservedObject var service: BarcodeScannerService
    var autoEnableTorch: Bool = false
    var instruction: String? = nil
    var onCancel: () -> Void
    
    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            
            // Camera Preview
            if service.permissionStatus == .authorized {
                CameraPreview(session: service.session)
                    .ignoresSafeArea()
            } else if service.permissionStatus == .denied || service.permissionStatus == .restricted {
                VStack(spacing: 20) {
                    Text("Camera Access Required")
                        .font(.title2.bold())
                        .foregroundColor(Colors.textPrimary)
                    
                    Text("To scan barcodes, please enable camera access in Settings.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(Colors.textSecondary)
                        .padding(.horizontal, 32)
                    
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .padding()
                    .background(MissionTheme.primaryButtonGradient)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
            
            // Overlay with "Hole Punch"
            if service.permissionStatus == .authorized {
                ScannerOverlay()
                    .ignoresSafeArea()
            }
            
            // UI Controls
            VStack {
                HStack {
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(MissionTheme.successScrim)
                            .clipShape(Circle())
                    }
                    .padding(.leading, 20)
                    .padding(.top, 50) 
                    
                    Spacer()

                    if service.permissionStatus == .authorized, service.isTorchAvailable {
                        Button(action: { service.toggleTorch() }) {
                            Image(systemName: service.isTorchEnabled ? "bolt.fill" : "bolt.slash.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(service.isTorchEnabled ? Colors.accentTeal : .white)
                                .padding(12)
                                .background(MissionTheme.successScrim)
                                .clipShape(Circle())
                        }
                        .padding(.trailing, 20)
                        .padding(.top, 50)
                    }
                }
                
                Spacer()

                if service.permissionStatus == .authorized {
                    Text(instruction ?? "Place a QR/Barcode inside the rectangle")
                        .font(.headline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(MissionTheme.successScrim)
                        .cornerRadius(12)
                        .padding(.bottom, 50)
                }
            }
        }
        .onAppear {
            if service.permissionStatus == .notDetermined {
                service.requestPermission()
            }
            // If already authorized or once authorized, setup is handled by service or caller
            // But we typically want to ensure session is ready
            if service.permissionStatus == .authorized {
                service.setupSession()
                service.startSession()
                if autoEnableTorch {
                    service.setTorch(enabled: true)
                }
            }
        }
        .onChange(of: service.permissionStatus) { _, status in
            if status == .authorized {
                service.setupSession()
                service.startSession()
                if autoEnableTorch {
                    service.setTorch(enabled: true)
                }
            }
        }
        .onDisappear {
            service.setTorch(enabled: false)
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        // Keep the layer bound to the live session. The backing layer tracks the
        // view's bounds automatically, so there is no manual frame math here.
        if uiView.videoPreviewLayer.session !== session {
            uiView.videoPreviewLayer.session = session
        }
    }

    /// Hosts the camera feed in the view's *backing* layer so it always fills the
    /// view. The previous sublayer approach left the preview layer at a `.zero`
    /// frame on first layout, which rendered as an all-black camera feed.
    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

struct ScannerOverlay: View {
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            // Define scan area size (e.g., 70% width, aspect 2:1 roughly for barcodes)
            let scanWidth = width * 0.8
            let scanHeight = scanWidth * 0.6
            
            let scanRect = CGRect(
                x: (width - scanWidth) / 2,
                y: (height - scanHeight) / 2,
                width: scanWidth,
                height: scanHeight
            )
            
            ZStack {
                // Dimmed background with transparent center window.
                MissionTheme.successScrim
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .frame(width: scanWidth, height: scanHeight)
                            .position(x: width / 2, y: height / 2)
                            .blendMode(.destinationOut)
                    )
                    .compositingGroup()
                
                // Border frame
                RoundedRectangle(cornerRadius: 12)
                    .stroke(MissionTheme.isTiimo ? Colors.accentBlue : Color.white, lineWidth: 3)
                    .frame(width: scanWidth, height: scanHeight)
                    .position(x: width / 2, y: height / 2)
            }
        }
    }
}
