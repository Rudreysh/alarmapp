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

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        view.videoPreviewLayer.connection?.videoOrientation = .portrait
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        if uiView.videoPreviewLayer.session !== session {
            uiView.videoPreviewLayer.session = session
        }
        uiView.videoPreviewLayer.connection?.videoOrientation = .portrait
    }

    /// Hosts the camera feed in the view's *backing* layer so it always fills the
    /// view. The previous sublayer approach left the preview layer at a `.zero`
    /// frame on first layout, which rendered as an all-black camera feed.
    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
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
                    // Favour recall over precision: keep a generous candidate set so
                    // everyday items are still recognised when the top guess is a
                    // generic category (e.g. "tableware" instead of "coffee mug").
                    let labels = (request.results ?? [])
                        .filter { $0.confidence > 0.02 }
                        .prefix(30)
                        .map { $0.identifier.lowercased() }
                    continuation.resume(returning: Array(labels))
                } catch {
                    continuation.resume(returning: [])
                }
            }
        }
    }

    /// Lenient match used by both Object Hunt and Household Item Hunt.
    /// Matches on substring containment in either direction *and* on shared
    /// whole words, so "mug" / "coffee mug" / "cup" all satisfy a coffee-mug
    /// target even when Vision only returns one of them.
    static func matches(targetKeywords: [String], labels: [String]) -> Bool {
        let normalizedLabels = labels.map(normalizeForMatch)
        let normalizedKeywords = targetKeywords.map(normalizeForMatch).filter { !$0.isEmpty }
        for label in normalizedLabels {
            let labelWords = Set(label.split(separator: " ").map(String.init).filter { $0.count > 2 })
            for keyword in normalizedKeywords {
                if label.contains(keyword) || keyword.contains(label) {
                    return true
                }
                let keywordWords = Set(keyword.split(separator: " ").map(String.init).filter { $0.count > 2 })
                if !labelWords.isDisjoint(with: keywordWords) {
                    return true
                }
            }
        }
        return false
    }

    private static func normalizeForMatch(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
