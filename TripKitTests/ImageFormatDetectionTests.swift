import XCTest
@testable import TripKit

final class ImageFormatDetectionTests: XCTestCase {

    func testDetect_PNGSignature() {
        let data = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x00])
        XCTAssertEqual(ImageFormatDetection.detect(data), .png)
    }

    func testDetect_JPEGSignature() {
        let data = Data([0xFF, 0xD8, 0xFF, 0xE0, 0, 0, 0, 0, 0, 0, 0, 0])
        XCTAssertEqual(ImageFormatDetection.detect(data), .jpeg)
    }

    func testDetect_HEICSignature() {
        // 0x66747970 = "ftyp"; 0x68656963 = "heic"
        let data = Data([0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70, 0x68, 0x65, 0x69, 0x63])
        XCTAssertEqual(ImageFormatDetection.detect(data), .heic)
    }

    func testDetect_UnknownReturnsNil() {
        let data = Data([0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B])
        XCTAssertNil(ImageFormatDetection.detect(data))
    }

    func testDetect_TooShortReturnsNil() {
        XCTAssertNil(ImageFormatDetection.detect(Data([0x89, 0x50, 0x4E])))
    }

    func testFileExtension_MapsCorrectly() {
        XCTAssertEqual(ImageFormat.png.fileExtension, "png")
        XCTAssertEqual(ImageFormat.jpeg.fileExtension, "jpg")
        XCTAssertEqual(ImageFormat.heic.fileExtension, "heic")
    }
}
