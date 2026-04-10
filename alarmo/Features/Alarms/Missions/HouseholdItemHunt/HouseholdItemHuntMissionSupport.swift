import Foundation
import SwiftUI
import UIKit
import Vision

enum HouseholdItemHuntMissionError: LocalizedError {
    case referenceImageMissing
    case featurePrintUnavailable

    var errorDescription: String? {
        switch self {
        case .referenceImageMissing:
            return "Reference image is missing. Please configure the mission again."
        case .featurePrintUnavailable:
            return "Could not analyze image similarity. Please try another photo."
        }
    }
}

struct HouseholdItemHuntMissionConfig: Codable, Equatable {
    var referenceImageFilename: String
}

enum HouseholdItemHuntImageStore {
    private static let folderName = "HouseholdItemHunt"

    static func saveReferenceImage(_ image: UIImage, replacing existingFilename: String? = nil) throws -> String {
        let filename = sanitizedFilename(existingFilename ?? "\(UUID().uuidString).jpg")
        let url = try imageURL(for: filename, createDirectory: true)
        let normalizedImage = image.normalizedForMission(maxDimension: 1280)

        guard let data = normalizedImage.jpegData(compressionQuality: 0.88) else {
            throw HouseholdItemHuntMissionError.featurePrintUnavailable
        }

        try data.write(to: url, options: .atomic)
        return filename
    }

    static func loadReferenceImage(filename: String) -> UIImage? {
        do {
            let url = try imageURL(for: filename)
            return UIImage(contentsOfFile: url.path)
        } catch {
            return nil
        }
    }

    static func deleteReferenceImage(filename: String) {
        do {
            let url = try imageURL(for: filename)
            try? FileManager.default.removeItem(at: url)
        } catch {
            // Best-effort cleanup only.
        }
    }

    private static func imageURL(for filename: String, createDirectory: Bool = false) throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let folder = base.appendingPathComponent(folderName, isDirectory: true)

        if createDirectory {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }

        return folder.appendingPathComponent(sanitizedFilename(filename), isDirectory: false)
    }

    private static func sanitizedFilename(_ filename: String) -> String {
        filename.replacingOccurrences(of: "/", with: "_")
    }
}

struct HouseholdItemHuntMatchResult {
    let fullDistance: Float
    let fullThreshold: Float
    let centerDistance: Float
    let centerThreshold: Float
    let hashDistance: Int
    let hashThreshold: Int

    var isMatch: Bool {
        fullDistance <= fullThreshold &&
        centerDistance <= centerThreshold &&
        hashDistance <= hashThreshold
    }

    var similarityPercent: Int {
        let fullScore = max(0, min(1, 1 - (fullDistance / max(fullThreshold * 2.0, 1))))
        let centerScore = max(0, min(1, 1 - (centerDistance / max(centerThreshold * 2.0, 1))))
        let hashScore = max(0, min(1, 1 - (Float(hashDistance) / Float(max(hashThreshold * 2, 1)))))
        let blended = (fullScore * 0.55) + (centerScore * 0.30) + (hashScore * 0.15)
        return Int((blended * 100).rounded())
    }
}

final class HouseholdItemHuntMatcher {
    static let shared = HouseholdItemHuntMatcher()
    private init() {}

    func evaluate(
        reference: UIImage,
        candidate: UIImage,
        fullThreshold: Float = 7.5,
        centerThreshold: Float = 8.5,
        hashThreshold: Int = 12
    ) async throws -> HouseholdItemHuntMatchResult {
        let referenceFeature = try Self.featurePrint(for: reference)
        let candidateFeature = try Self.featurePrint(for: candidate)
        let referenceCenterFeature = try Self.featurePrint(for: reference, centerCropRatio: 0.72)
        let candidateCenterFeature = try Self.featurePrint(for: candidate, centerCropRatio: 0.72)
        let referenceHash = try Self.averageHash(for: reference)
        let candidateHash = try Self.averageHash(for: candidate)

        var fullDistance: Float = .greatestFiniteMagnitude
        try referenceFeature.computeDistance(&fullDistance, to: candidateFeature)

        var centerDistance: Float = .greatestFiniteMagnitude
        try referenceCenterFeature.computeDistance(&centerDistance, to: candidateCenterFeature)

        let hashDistance = Self.hammingDistance(referenceHash, candidateHash)
        return HouseholdItemHuntMatchResult(
            fullDistance: fullDistance,
            fullThreshold: fullThreshold,
            centerDistance: centerDistance,
            centerThreshold: centerThreshold,
            hashDistance: hashDistance,
            hashThreshold: hashThreshold
        )
    }

    private static func featurePrint(for image: UIImage, centerCropRatio: CGFloat? = nil) throws -> VNFeaturePrintObservation {
        let preparedImage: UIImage
        if let centerCropRatio {
            preparedImage = image.centerSquareCrop(ratio: centerCropRatio)
        } else {
            preparedImage = image
        }
        let normalizedImage = preparedImage.normalizedForMission(maxDimension: 1024)
        guard let cgImage = normalizedImage.cgImage else {
            throw HouseholdItemHuntMissionError.featurePrintUnavailable
        }

        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        try handler.perform([request])

        guard let observation = request.results?.first as? VNFeaturePrintObservation else {
            throw HouseholdItemHuntMissionError.featurePrintUnavailable
        }

        return observation
    }

    private static func averageHash(for image: UIImage) throws -> UInt64 {
        let normalizedImage = image.normalizedForMission(maxDimension: 256)
        guard let cgImage = normalizedImage.cgImage else {
            throw HouseholdItemHuntMissionError.featurePrintUnavailable
        }

        let width = 8
        let height = 8
        let bytesPerRow = width
        var pixels = [UInt8](repeating: 0, count: width * height)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            throw HouseholdItemHuntMissionError.featurePrintUnavailable
        }

        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let mean = Int(pixels.reduce(0, +)) / pixels.count
        var hash: UInt64 = 0
        for (index, value) in pixels.enumerated() {
            if Int(value) >= mean {
                hash |= (UInt64(1) << UInt64(index))
            }
        }
        return hash
    }

    private static func hammingDistance(_ lhs: UInt64, _ rhs: UInt64) -> Int {
        (lhs ^ rhs).nonzeroBitCount
    }
}

private extension UIImage {
    func normalizedForMission(maxDimension: CGFloat) -> UIImage {
        let maxCurrentDimension = max(size.width, size.height)
        guard maxCurrentDimension > maxDimension else {
            return redraw(size: size)
        }

        let scale = maxDimension / maxCurrentDimension
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        return redraw(size: newSize)
    }

    private func redraw(size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    func centerSquareCrop(ratio: CGFloat) -> UIImage {
        guard let cgImage = self.cgImage else { return self }
        let clampedRatio = max(0.35, min(1.0, ratio))
        let minSide = min(CGFloat(cgImage.width), CGFloat(cgImage.height))
        let side = minSide * clampedRatio
        let x = (CGFloat(cgImage.width) - side) / 2.0
        let y = (CGFloat(cgImage.height) - side) / 2.0
        let rect = CGRect(x: x, y: y, width: side, height: side).integral
        guard let cropped = cgImage.cropping(to: rect) else { return self }
        return UIImage(cgImage: cropped, scale: scale, orientation: .up)
    }
}
