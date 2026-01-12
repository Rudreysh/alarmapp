import XCTest
@testable import alarmo

final class WallpaperCatalogLoaderTests: XCTestCase {
    
    // Test that the loader correctly finds categories and images, and ignores non-images.
    func test_loaderReturnsCategoriesAndItems() throws {
        // 1. Setup a temp directory simulating the bundle structure
        let root = try TestHelpers.makeTempDirectory()
        
        // Create "nature" category
        let natureURL = root.appendingPathComponent("nature", isDirectory: true)
        try FileManager.default.createDirectory(at: natureURL, withIntermediateDirectories: true)
        
        let nature1 = natureURL.appendingPathComponent("forest.jpg")
        let nature2 = natureURL.appendingPathComponent("lake.PNG") // Case insensitive check
        let nature3 = natureURL.appendingPathComponent("info.txt") // Should be ignored
        
        try createEmptyFile(at: nature1)
        try createEmptyFile(at: nature2)
        try createEmptyFile(at: nature3)
        
        // Create "abstract" category
        let abstractURL = root.appendingPathComponent("abstract", isDirectory: true)
        try FileManager.default.createDirectory(at: abstractURL, withIntermediateDirectories: true)
        
        let abstract1 = abstractURL.appendingPathComponent("shapes.jpeg")
        try createEmptyFile(at: abstract1)
        
        // Create empty category
        let emptyURL = root.appendingPathComponent("empty", isDirectory: true)
        try FileManager.default.createDirectory(at: emptyURL, withIntermediateDirectories: true)

        // 2. Run Loader
        let loader = BundleWallpaperCatalogLoader(rootURL: root, debugLogging: true)
        let categories = try loader.loadCategories()
        
        // 3. Assertions
        
        // Should find 2 categories (nature, abstract). Empty one should be skipped effectively or just have 0 items (my implementation skips empty categories in the loop: "if !items.isEmpty { ... }")
        XCTAssertEqual(categories.count, 2)
        
        // Sort order is title ascending. "abstract" comes before "nature".
        let firstCat = categories[0]
        XCTAssertEqual(firstCat.id, "abstract")
        XCTAssertEqual(firstCat.items.count, 1)
        XCTAssertEqual(firstCat.items.first?.id, "abstract-shapes.jpeg")
        
        let secondCat = categories[1]
        XCTAssertEqual(secondCat.id, "nature")
        XCTAssertEqual(secondCat.items.count, 2)
        
        // Verify items in nature
        let itemTitles = secondCat.items.map { $0.title }.sorted()
        // "forest.jpg" -> "Forest"
        // "lake.PNG" -> "Lake"
        XCTAssertEqual(itemTitles, ["Forest", "Lake"])
        
        // Verify non-image ignored
        XCTAssertFalse(secondCat.items.contains(where: { $0.url.lastPathComponent == "info.txt" }))
    }
    
    private func createEmptyFile(at url: URL) throws {
        FileManager.default.createFile(atPath: url.path, contents: Data())
    }
}
