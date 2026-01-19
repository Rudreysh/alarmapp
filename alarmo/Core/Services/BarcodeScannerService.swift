import AVFoundation
import Combine
import UIKit

class BarcodeScannerService: NSObject, ObservableObject {
    @Published var permissionStatus: AVAuthorizationStatus = .notDetermined
    @Published var scannedCode: (String, String)? // (value, type)
    @Published var isSessionRunning = false
    
    let session = AVCaptureSession()
    private let metadataOutput = AVCaptureMetadataOutput()
    private let sessionQueue = DispatchQueue(label: "com.alarmo.cameraQueue")
    
    override init() {
        super.init()
        checkPermission()
    }
    
    func checkPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        DispatchQueue.main.async {
            self.permissionStatus = status
        }
    }
    
    func requestPermission() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                self.permissionStatus = granted ? .authorized : .denied
            }
        }
    }
    
    func setupSession() {
        print("[BarcodeScannerService] Setting up session...")
        guard permissionStatus == .authorized else {
            print("[BarcodeScannerService] ❌ Permission not authorized: \(permissionStatus.rawValue)")
            return 
        }
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            if self.session.inputs.isEmpty {
                self.session.beginConfiguration()
                
                // Add input
                guard let videoDevice = AVCaptureDevice.default(for: .video) else {
                    print("[BarcodeScannerService] ❌ No video device found. (Simulator requires 'Feature -> Camera -> Use Mac Camera')")
                    self.session.commitConfiguration()
                    return
                }
                
                guard let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice) else {
                    print("[BarcodeScannerService] ❌ Could not create video device input")
                    self.session.commitConfiguration()
                    return
                }
                
                if self.session.canAddInput(videoDeviceInput) {
                    self.session.addInput(videoDeviceInput)
                    print("[BarcodeScannerService] ✅ Video input added")
                } else {
                    print("[BarcodeScannerService] ❌ Could not add video input")
                }
                
                // Add output
                if self.session.canAddOutput(self.metadataOutput) {
                    self.session.addOutput(self.metadataOutput)
                    
                    self.metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                    // Add all available barcode types
                    let availableTypes = self.metadataOutput.availableMetadataObjectTypes
                    // Filter specifically for barcodes/QR
                    let relevantTypes: [AVMetadataObject.ObjectType] = [
                        .qr, .ean13, .ean8, .code128, .code39, .upce, .pdf417, .aztec
                    ].filter { availableTypes.contains($0) }
                    
                    if !relevantTypes.isEmpty {
                        self.metadataOutput.metadataObjectTypes = relevantTypes
                        print("[BarcodeScannerService] ✅ Metadata output added with types: \(relevantTypes.map { $0.rawValue })")
                    } else {
                         print("[BarcodeScannerService] ⚠️ No relevant barcode types supported")
                    }
                } else {
                    print("[BarcodeScannerService] ❌ Could not add metadata output")
                }
                
                self.session.commitConfiguration()
                print("[BarcodeScannerService] Session configuration committed")
            } else {
                print("[BarcodeScannerService] Session inputs already configured")
            }
        }
    }
    
    func startSession() {
        print("[BarcodeScannerService] Requesting session start...")
        guard !session.isRunning else {
            print("[BarcodeScannerService] Session already running")
            return
        }
        sessionQueue.async {
            print("[BarcodeScannerService] invoking startRunning()")
            self.session.startRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = true
                print("[BarcodeScannerService] Session started (isSessionRunning = true)")
            }
        }
    }
    
    func stopSession() {
        guard session.isRunning else { return }
        sessionQueue.async {
            self.session.stopRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = false
            }
        }
    }
}

extension BarcodeScannerService: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first,
           let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
           let stringValue = readableObject.stringValue {
            
            Task { @MainActor in
                self.scannedCode = (stringValue, readableObject.type.rawValue)
            }
        }
    }
}
