import XCTest
import UIKit
@testable import FlipCardAlbum

final class AlbumTests: XCTestCase {
    func testDeviceAnimationEnvironment() {
        print("ANIMATION_ENV reduceMotion=\(UIAccessibility.isReduceMotionEnabled) lowPower=\(ProcessInfo.processInfo.isLowPowerModeEnabled) maxFPS=\(UIScreen.main.maximumFramesPerSecond) os=\(UIDevice.current.systemVersion)")
    }
    func testWrapAndDirection() {
        var state = AlbumState()
        state.turn(-1)
        XCTAssertEqual(state.page, 1)
        XCTAssertEqual(state.direction, -1)
        state.turn(1)
        XCTAssertEqual(state.page, 0)
        XCTAssertEqual(state.revision, 2)
    }
    func testPhotoPaginationAndPersistenceSchema() throws {
        var state = AlbumState()
        state.photos = ["single.png"]
        XCTAssertEqual(state.pageCount, 1)
        state.turn(-1)
        XCTAssertEqual(state.page, 0)
        state.photos = (0..<9).map { "\($0).png" }
        state.transparent = true
        XCTAssertEqual(state.pageCount, 3)
        XCTAssertEqual(try JSONDecoder().decode(AlbumState.self, from: JSONEncoder().encode(state)), state)
    }
    func testLargePhotoImportIsBoundedAndPreservesAlpha() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let original = UIGraphicsImageRenderer(size: CGSize(width: 2400, height: 1800), format: format).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 600, y: 450, width: 1200, height: 900))
        }
        let name = try AlbumStore.importImage(XCTUnwrap(original.pngData()))
        let path = try AlbumStore.directory.appendingPathComponent(name)
        defer { try? FileManager.default.removeItem(at: path) }
        let imported = try XCTUnwrap(UIImage(contentsOfFile: path.path)?.cgImage)
        XCTAssertEqual(imported.width, 600)
        XCTAssertEqual(imported.height, 450)
        XCTAssertEqual(try alpha(in: imported, x: 0, y: 0), 0)
        XCTAssertEqual(try alpha(in: imported, x: 300, y: 225), 255)
    }
    func testInvalidPhotoDataFailsExplicitly() {
        XCTAssertThrowsError(try AlbumStore.importImage(Data("not an image".utf8))) { error in
            XCTAssertEqual((error as NSError).code, CocoaError.fileReadCorruptFile.rawValue)
        }
    }
    private func alpha(in image: CGImage, x: Int, y: Int) throws -> UInt8 {
        let pixelImage = try XCTUnwrap(image.cropping(to: CGRect(x: x, y: y, width: 1, height: 1)))
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = try XCTUnwrap(CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(pixelImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return pixel[3]
    }
}
