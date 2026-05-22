import XCTest
@testable import alarmo

final class FileStorageServiceTests: XCTestCase {
    func test_saveImageData_writesFile() throws {
        let tempDir = try TestHelpers.makeTempDirectory()
        let service = LocalFileStorageService(baseURL: tempDir)
        let data = Data([0x01, 0x02, 0x03])

        let url = try service.saveImageData(data, fileExtension: "jpg")
        let saved = try Data(contentsOf: url)

        XCTAssertEqual(saved, data)
    }
}
