import XCTest
final class AlbumUITests: XCTestCase {
    private func capture(_ name: String, app: XCUIApplication) {
        print("QA_TIME \(Date().timeIntervalSince1970) \(name)")
        print("APP_CAPTURE \(name)\n\(app.debugDescription)")
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = name
        image.lifetime = .keepAlways
        add(image)
    }

    func testAppMotionAndPickerDiscovery() {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(app.staticTexts["pageNumber"].waitForExistence(timeout: 10))
        capture("app-motion-before", app: app)
        app.buttons["nextPage"].tap()
        Thread.sleep(forTimeInterval: 4)
        capture("app-motion-next", app: app)
        app.buttons["previousPage"].tap()
        Thread.sleep(forTimeInterval: 4)
        capture("app-motion-previous", app: app)
        app.buttons["选择卡册照片"].tap()
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 30), app.debugDescription)
        capture("photo-picker", app: app)
        app.buttons["Cancel"].tap()
    }

    func testPhotoPickerReady() {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(app.buttons["选择卡册照片"].waitForExistence(timeout: 10))
        app.buttons["选择卡册照片"].tap()
        XCTAssertTrue(app.navigationBars["照片"].waitForExistence(timeout: 30), app.debugDescription)
        capture("photo-picker-ready", app: app)
        app.buttons["Cancel"].tap()
    }

    func testPhotoImportsAndPersistence() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["QA_PHOTO_FIXTURES"] == "1",
                          "Requires five synthetic QA photos in a dedicated simulator; see UITests/README.md")
        continueAfterFailure = false
        let app = XCUIApplication(); app.launch()
        let page = app.staticTexts["pageNumber"]
        XCTAssertTrue(page.waitForExistence(timeout: 10))
        let original = page.label
        func openPicker() {
            app.buttons["选择卡册照片"].tap()
            XCTAssertTrue(app.images.matching(identifier: "PXGGridLayout-Info").firstMatch.waitForExistence(timeout: 30), app.debugDescription)
        }
        openPicker()
        app.buttons["Cancel"].tap()
        XCTAssertEqual(page.label, original)
        capture("zero-cancel-unchanged", app: app)
        openPicker()
        app.images.matching(identifier: "PXGGridLayout-Info").element(boundBy: 0).tap()
        app.buttons["完成"].tap()
        expectation(for: NSPredicate(format: "label == %@", "1 / 1"), evaluatedWith: page)
        waitForExpectations(timeout: 15)
        capture("one-photo-imported", app: app)
        app.buttons["nextPage"].tap()
        XCTAssertEqual(page.label, "1 / 1")
        app.switches["transparentToggle"].tap()
        let transparency = app.switches["transparentToggle"].value as? String
        app.terminate(); app.launch()
        XCTAssertTrue(page.waitForExistence(timeout: 10))
        XCTAssertEqual(page.label, "1 / 1")
        XCTAssertEqual(app.switches["transparentToggle"].value as? String, transparency)
        capture("one-photo-relaunched", app: app)
        openPicker()
        for index in 0..<5 { app.images.matching(identifier: "PXGGridLayout-Info").element(boundBy: index).tap() }
        app.buttons["完成"].tap()
        expectation(for: NSPredicate(format: "label == %@", "1 / 2"), evaluatedWith: page)
        waitForExpectations(timeout: 15)
        capture("five-photos-imported", app: app)
        app.buttons["nextPage"].tap()
        XCTAssertEqual(page.label, "2 / 2")
        capture("five-photos-page-two", app: app)
        app.buttons["nextPage"].tap()
        XCTAssertEqual(page.label, "1 / 2")
        app.buttons["previousPage"].tap()
        XCTAssertEqual(page.label, "2 / 2")
        app.terminate(); app.launch()
        XCTAssertTrue(page.waitForExistence(timeout: 10))
        XCTAssertEqual(page.label, "2 / 2")
        capture("five-photos-relaunched", app: app)
    }

    func testFlipAndTransparency() {
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(app.staticTexts["pageNumber"].waitForExistence(timeout: 10))
        let initialToggle = app.switches["transparentToggle"].value as? String
        defer { if app.switches["transparentToggle"].value as? String != initialToggle { app.switches["transparentToggle"].tap() } }
        let before = app.staticTexts["pageNumber"].label
        app.buttons["nextPage"].tap()
        XCTAssertNotEqual(app.staticTexts["pageNumber"].label, before)
        app.buttons["previousPage"].tap()
        XCTAssertEqual(app.staticTexts["pageNumber"].label, before)
        app.switches["transparentToggle"].tap()
    }
}
