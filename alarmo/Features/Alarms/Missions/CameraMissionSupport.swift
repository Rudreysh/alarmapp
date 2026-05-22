import SwiftUI
import AVFoundation
import Vision
import UIKit
import Combine

struct PoseMetrics: Equatable {
    var shoulderY: CGFloat
    var hipY: CGFloat
    var wristY: CGFloat
    var ankleY: CGFloat
    var confidence: CGFloat
}

final class MissionCameraSession: NSObject, ObservableObject {
    @Published var permissionDenied: Bool = false
    @Published var poseMetrics: PoseMetrics?

    let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "alarmo.mission.camera.session", qos: .userInitiated)
    private let analysisQueue = DispatchQueue(label: "alarmo.mission.camera.analysis", qos: .userInitiated)

    private var configured = false
    private var isAnalyzingFrame = false

    func start() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            startSessionIfNeeded()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.startSessionIfNeeded()
                    } else {
                        self?.permissionDenied = true
                    }
                }
            }
        case .restricted, .denied:
            permissionDenied = true
        @unknown default:
            permissionDenied = true
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    private func startSessionIfNeeded() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.configured {
                self.configureSession()
            }
            guard self.configured, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        defer {
            session.commitConfiguration()
        }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else {
            return
        }

        session.addInput(input)

        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(self, queue: analysisQueue)

        guard session.canAddOutput(output) else { return }
        session.addOutput(output)

        if let connection = output.connection(with: .video), connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }

        configured = true
    }

    private func analyzePose(sampleBuffer: CMSampleBuffer) {
        guard !isAnalyzingFrame else { return }
        isAnalyzingFrame = true
        defer { isAnalyzingFrame = false }

        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .right, options: [:])

        do {
            try handler.perform([request])
            guard let observation = request.results?.first else {
                DispatchQueue.main.async { self.poseMetrics = nil }
                return
            }

            let points = try observation.recognizedPoints(.all)

            guard let leftShoulder = points[.leftShoulder],
                  let rightShoulder = points[.rightShoulder],
                  let leftHip = points[.leftHip],
                  let rightHip = points[.rightHip],
                  leftShoulder.confidence > 0.2,
                  rightShoulder.confidence > 0.2,
                  leftHip.confidence > 0.2,
                  rightHip.confidence > 0.2
            else {
                DispatchQueue.main.async { self.poseMetrics = nil }
                return
            }

            let shoulderY = CGFloat((leftShoulder.y + rightShoulder.y) / 2)
            let hipY = CGFloat((leftHip.y + rightHip.y) / 2)

            let wristCandidates = [points[.leftWrist], points[.rightWrist]].compactMap { $0 }.filter { $0.confidence > 0.15 }
            let ankleCandidates = [points[.leftAnkle], points[.rightAnkle]].compactMap { $0 }.filter { $0.confidence > 0.15 }

            let wristY: CGFloat
            if wristCandidates.isEmpty {
                wristY = shoulderY
            } else {
                let avg = wristCandidates.map { Double($0.y) }.reduce(0, +) / Double(wristCandidates.count)
                wristY = CGFloat(avg)
            }

            let ankleY: CGFloat
            if ankleCandidates.isEmpty {
                ankleY = hipY - 0.3
            } else {
                let avg = ankleCandidates.map { Double($0.y) }.reduce(0, +) / Double(ankleCandidates.count)
                ankleY = CGFloat(avg)
            }

            let confidence = CGFloat((leftShoulder.confidence + rightShoulder.confidence + leftHip.confidence + rightHip.confidence) / 4)
            let metrics = PoseMetrics(shoulderY: shoulderY, hipY: hipY, wristY: wristY, ankleY: ankleY, confidence: confidence)
            DispatchQueue.main.async { self.poseMetrics = metrics }
        } catch {
            DispatchQueue.main.async { self.poseMetrics = nil }
        }
    }
}

extension MissionCameraSession: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        analyzePose(sampleBuffer: sampleBuffer)
    }
}

struct MissionCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        previewLayer.connection?.videoOrientation = .portrait
        view.layer.addSublayer(previewLayer)

        context.coordinator.previewLayer = previewLayer
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.previewLayer?.frame = uiView.bounds
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}

enum ObjectHuntMatcher {
    static func classify(image: UIImage) async -> [String] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let cgImage = image.cgImage else {
                    continuation.resume(returning: [])
                    return
                }

                let request = VNClassifyImageRequest()
                let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])

                do {
                    try handler.perform([request])
                    let labels = (request.results ?? [])
                        .filter { $0.confidence > 0.05 }
                        .prefix(10)
                        .map { $0.identifier.lowercased() }
                    continuation.resume(returning: Array(labels))
                } catch {
                    continuation.resume(returning: [])
                }
            }
        }
    }

    static func matches(targetKeywords: [String], labels: [String]) -> Bool {
        let normalizedKeywords = targetKeywords.map { $0.lowercased() }
        for label in labels {
            for keyword in normalizedKeywords {
                if label.contains(keyword) || keyword.contains(label) {
                    return true
                }
            }
        }
        return false
    }
}
