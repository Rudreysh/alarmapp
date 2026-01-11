import XCTest
@testable import alarmo

final class WallpaperCatalogLoaderTests: XCTestCase {
    func test_loaderReturnsCategoriesAndItems() throws {
        let root = try TestHelpers.makeTempDirectory()
        let categoryURL = root.appendingPathComponent("abstract", isDirectory: true)
        try FileManager.default.createDirectory(at: categoryURL, withIntermediateDirectories: true)

        let file1 = categoryURL.appendingPathComponent("first.jpg")
        let file2 = categoryURL.appendingPathComponent("second.png")
        let file3 = categoryURL.appendingPathComponent("note.txt")
        FileManager.default.createFile(atPath: file1.path, contents: Data())
        FileManager.default.createFile(atPath: file2.path, contents: Data())
        FileManager.default.createFile(atPath: file3.path, contents: Data())

        let loader = BundleWallpaperCatalogLoader(rootURL: root)
        let categories = try loader.loadCategories()

        XCTAssertEqual(categories.count, 1)
        XCTAssertEqual(categories[0].items.count, 2)
    }
}
