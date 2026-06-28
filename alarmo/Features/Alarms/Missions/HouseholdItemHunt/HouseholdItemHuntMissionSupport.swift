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
    var selectedItemIDs: [String] = []
    var referenceImageFilename: String? = nil
    var customItemsJSON: String? = nil
}

enum HouseholdItemHuntCatalogSection: String, CaseIterable, Identifiable {
    case household

    var id: String { rawValue }

    var title: String {
        switch self {
        case .household: return "Household Items"
        }
    }
}

struct HouseholdItemHuntCatalogItem: Identifiable, Hashable {
    let id: String
    let name: String
    let emoji: String
    let keywords: [String]
    let referenceImageFilename: String?

    var isCustom: Bool { referenceImageFilename != nil }

    init(
        id: String,
        name: String,
        emoji: String,
        keywords: [String],
        referenceImageFilename: String? = nil
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.keywords = keywords
        self.referenceImageFilename = referenceImageFilename
    }
}

enum HouseholdItemHuntCatalogStore {
    static let selectedItemIDsKey = "selectedItemIDs"
    static let referenceImageFilenameKey = "referenceImageFilename"
    static let customItemsKey = "customItems"

    static var builtInItems: [HouseholdItemHuntCatalogItem] {
        householdItems
    }

    static var allItems: [HouseholdItemHuntCatalogItem] {
        builtInItems
    }

    static func allItems(for mission: AlarmMission) -> [HouseholdItemHuntCatalogItem] {
        builtInItems + customItems(from: mission)
    }

    static func items(in section: HouseholdItemHuntCatalogSection) -> [HouseholdItemHuntCatalogItem] {
        switch section {
        case .household: return householdItems
        }
    }

    static func item(withID id: String) -> HouseholdItemHuntCatalogItem? {
        allItems.first { $0.id == id }
    }

    static func configuredSelectionIDs(from mission: AlarmMission) -> Set<String> {
        guard let stored = mission.customData[selectedItemIDsKey], !stored.isEmpty else {
            return []
        }
        let allIDs = Set(allItems(for: mission).map(\.id))
        let ids = Set(
            stored
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
        return ids.intersection(allIDs)
    }

    static func selectedIDsForEditing(from mission: AlarmMission) -> Set<String> {
        let configured = configuredSelectionIDs(from: mission)
        return configured.isEmpty ? defaultSelectionIDs : configured
    }

    static func selectedItems(for mission: AlarmMission) -> [HouseholdItemHuntCatalogItem] {
        let missionItems = allItems(for: mission)
        let configured = configuredSelectionIDs(from: mission)
        if configured.isEmpty {
            if let legacyReference = mission.customData[referenceImageFilenameKey], !legacyReference.isEmpty {
                return []
            }
            return defaultItems
        }

        return missionItems.filter { configured.contains($0.id) }
    }

    static func pickRandomItem(for mission: AlarmMission) -> HouseholdItemHuntCatalogItem? {
        selectedItems(for: mission).randomElement()
    }

    static func serializedIDs(_ ids: Set<String>) -> String {
        ids.sorted().joined(separator: ",")
    }

    static func customItems(from mission: AlarmMission) -> [HouseholdItemHuntCatalogItem] {
        guard let raw = mission.customData[customItemsKey], !raw.isEmpty else { return [] }
        guard let data = raw.data(using: .utf8) else { return [] }
        guard let decoded = try? JSONDecoder().decode([StoredCustomItem].self, from: data) else { return [] }

        return decoded.compactMap { stored in
            guard !stored.id.isEmpty,
                  !stored.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  let filename = stored.referenceImageFilename,
                  !filename.isEmpty else {
                return nil
            }

            let generatedKeywords = keywords(from: stored.name)
            let mergedKeywords = Array(Set((stored.keywords ?? []) + generatedKeywords)).sorted()
            return HouseholdItemHuntCatalogItem(
                id: stored.id,
                name: stored.name,
                emoji: stored.emoji.isEmpty ? "🧩" : stored.emoji,
                keywords: mergedKeywords.isEmpty ? generatedKeywords : mergedKeywords,
                referenceImageFilename: filename
            )
        }
    }

    static func serializedCustomItems(_ items: [HouseholdItemHuntCatalogItem]) -> String? {
        let customItems = items.filter { $0.isCustom }
        guard !customItems.isEmpty else { return nil }

        let payload = customItems.map {
            StoredCustomItem(
                id: $0.id,
                name: $0.name,
                emoji: $0.emoji,
                keywords: $0.keywords,
                referenceImageFilename: $0.referenceImageFilename
            )
        }
        guard let data = try? JSONEncoder().encode(payload) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func makeCustomItem(
        name: String,
        referenceImageFilename: String,
        existingCustomItems: [HouseholdItemHuntCatalogItem]
    ) -> HouseholdItemHuntCatalogItem {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let emoji = customEmojiPool[existingCustomItems.count % customEmojiPool.count]
        return HouseholdItemHuntCatalogItem(
            id: "custom_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))",
            name: trimmedName,
            emoji: emoji,
            keywords: keywords(from: trimmedName),
            referenceImageFilename: referenceImageFilename
        )
    }

    static func matches(item: HouseholdItemHuntCatalogItem, labels: [String]) -> Bool {
        if item.id == "keys", isLikelyModernKeyMatch(labels: labels.map(normalizeToken)) {
            return true
        }
        // Delegate to the shared lenient matcher (substring + whole-word overlap).
        return ObjectHuntMatcher.matches(targetKeywords: item.keywords, labels: labels)
    }

    static func primaryDetectedLabel(from labels: [String]) -> String? {
        guard let top = labels.first else { return nil }
        let cleaned = top
            .split(separator: ",")
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        guard let cleaned, !cleaned.isEmpty else { return nil }
        return cleaned.lowercased()
    }

    static func articlePhrase(for noun: String) -> String {
        guard let first = noun.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().first else {
            return noun
        }
        let article = "aeiou".contains(first) ? "an" : "a"
        return "\(article) \(noun)"
    }

    static var defaultSelectionIDs: Set<String> {
        Set(defaultItems.prefix(8).map(\.id))
    }

    private static var defaultItems: [HouseholdItemHuntCatalogItem] {
        householdItems
    }

    nonisolated private static func normalizeToken(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func keywords(from name: String) -> [String] {
        let lowered = normalizeToken(name)
        let parts = lowered
            .split(separator: " ")
            .map(String.init)
            .filter { $0.count > 1 }
        return Array(Set(([lowered] + parts))).sorted()
    }

    nonisolated private static func isLikelyModernKeyMatch(labels: [String]) -> Bool {
        let disallowedToolWords = ["hammer", "screwdriver", "wrench", "drill", "pliers", "saw", "spanner"]
        for label in labels {
            if label.contains("key") && !label.contains("keyboard") {
                return true
            }
            if label.contains("keychain") || label.contains("fob") || label.contains("car key") || label.contains("door key") {
                return true
            }
            if label.contains("tool") && !disallowedToolWords.contains(where: label.contains) {
                return true
            }
        }
        return false
    }

    private static let customEmojiPool = ["🧩", "📸", "🏷️", "📦", "🪄", "🔎", "🛍️", "🧸"]

    private struct StoredCustomItem: Codable {
        let id: String
        let name: String
        let emoji: String
        let keywords: [String]?
        let referenceImageFilename: String?
    }

    private static let householdItems: [HouseholdItemHuntCatalogItem] = [
        .init(id: "toothbrush", name: "Toothbrush", emoji: "🪥", keywords: ["toothbrush", "brush", "electric toothbrush", "toothpaste"]),
        .init(id: "running_faucet", name: "Running Faucet", emoji: "🚰", keywords: ["faucet", "tap", "running water", "sink", "basin"]),
        .init(id: "shoes", name: "Shoes", emoji: "👟", keywords: ["shoe", "sneaker", "footwear", "boot", "trainer", "running shoe"]),
        .init(id: "fridge", name: "Fridge", emoji: "🧊", keywords: ["fridge", "refrigerator", "freezer"]),
        .init(id: "keys", name: "Keys", emoji: "🗝️", keywords: ["keys", "key", "keychain", "house key", "car key", "door key", "key fob", "fob"]),
        .init(id: "coffee_mug", name: "Coffee Mug", emoji: "☕️", keywords: ["mug", "coffee mug", "coffee cup", "cup", "coffee", "espresso", "tea cup", "teacup", "drinkware"]),
        .init(id: "mirror", name: "Mirror", emoji: "🪞", keywords: ["mirror", "looking glass"]),
        .init(id: "water_bottle", name: "Water Bottle", emoji: "🍶", keywords: ["water bottle", "bottle", "flask", "thermos", "canteen"]),
        .init(id: "dustpan", name: "Dustpan", emoji: "🪣", keywords: ["dustpan", "scoop", "bucket"]),
        .init(id: "toilet", name: "Toilet", emoji: "🚽", keywords: ["toilet", "toilet bowl", "lavatory"]),
        .init(id: "book", name: "Book", emoji: "📚", keywords: ["book", "notebook", "novel", "textbook", "paperback", "hardcover"]),
        .init(id: "lamp", name: "Lamp", emoji: "💡", keywords: ["lamp", "desk lamp", "light", "lampshade", "table lamp"]),
        .init(id: "tv_remote", name: "TV Remote", emoji: "📺", keywords: ["remote", "remote control", "tv remote", "controller"]),
        .init(id: "front_door", name: "Front Door", emoji: "🚪", keywords: ["door", "front door", "doorway"]),
        .init(id: "stove", name: "Stove", emoji: "🍳", keywords: ["stove", "oven", "range", "cooktop", "burner"]),
        .init(id: "lotion_bottle", name: "Lotion Bottle", emoji: "🧴", keywords: ["lotion", "lotion bottle", "bottle", "moisturizer", "sunscreen", "shampoo"]),
        .init(id: "soap", name: "Soap", emoji: "🧼", keywords: ["soap", "soap bar", "liquid soap", "hand soap", "soap dispenser"]),
        .init(id: "plant", name: "Plant", emoji: "🪴", keywords: ["plant", "flowerpot", "potted plant", "houseplant", "succulent"]),
        .init(id: "plate", name: "Plate", emoji: "🍽️", keywords: ["plate", "dish", "tableware", "dinner plate"]),
        .init(id: "towel", name: "Towel", emoji: "🧺", keywords: ["towel", "bath towel", "hand towel", "washcloth"]),
        .init(id: "backpack", name: "Backpack", emoji: "🎒", keywords: ["backpack", "bag", "school bag", "rucksack", "knapsack"]),
        .init(id: "headphones", name: "Headphones", emoji: "🎧", keywords: ["headphones", "headset", "earphones", "earbuds"]),
        .init(id: "shower", name: "Shower", emoji: "🚿", keywords: ["shower", "shower head", "showerhead"]),
        .init(id: "tape", name: "Tape", emoji: "🧻", keywords: ["tape", "adhesive tape", "scotch tape", "duct tape"])
    ]
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
