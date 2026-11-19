// SpringBoard acceptance, separate from App preview coverage.
import XCTest

final class WidgetHostTests: XCTestCase {
    private let app = XCUIApplication(bundleIdentifier: "com.lpkiki.FlipCardAlbum")
    private let home = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    private func button(_ labels: [String], in application: XCUIApplication) -> XCUIElement {
        application.buttons.matching(NSPredicate(format: "label IN %@", labels + labels.map { " " + $0 })).firstMatch
    }

    @discardableResult
    private func locateHostedWidget() -> Bool {
        let next = home.buttons["下一页"].firstMatch
        if next.waitForExistence(timeout: 2) { return true }
        home.swipeLeft()
        return next.waitForExistence(timeout: 5)
    }

    private func ensureHostedWidget() throws {
        if locateHostedWidget() { return }
        XCUIDevice.shared.press(.home)
        home.activate()
        home.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75)).press(forDuration: 1.5)
        let edit = button(["Edit", "编辑"], in: home)
        if edit.waitForExistence(timeout: 4) { edit.tap() }
        let add = button(["Add Widget", "Add Widgets", "添加小组件"], in: home)
        XCTAssertTrue(add.waitForExistence(timeout: 5), home.debugDescription)
        add.tap()
        let search = home.searchFields.matching(NSPredicate(format: "placeholderValue IN %@", ["搜索小组件", "Search Widgets"])).firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5), home.debugDescription)
        search.tap()
        search.typeText("翻页卡册")
        let result = home.staticTexts["翻页卡册"].firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5), home.debugDescription)
        result.tap()
        capture("medium-widget-gallery")
        let confirm = button(["Add Widget", "Add Widgets", "添加小组件"], in: home)
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), home.debugDescription)
        confirm.tap()
        let done = button(["Done", "完成"], in: home)
        if done.waitForExistence(timeout: 5) { done.tap() }
        XCTAssertTrue(home.buttons["下一页"].firstMatch.waitForExistence(timeout: 10), home.debugDescription)
    }

    private func capture(_ name: String) {
        print("QA_TIME \(Date().timeIntervalSince1970) \(name)")
        print("HOST_CAPTURE \(name)\n\(home.debugDescription)")
        let image = XCTAttachment(screenshot: home.screenshot())
        image.name = name
        image.lifetime = .keepAlways
        add(image)
        let tree = XCTAttachment(string: home.debugDescription)
        tree.name = name + " hierarchy"
        tree.lifetime = .keepAlways
        add(tree)
    }

    func testBothBackgroundModes() throws {
        continueAfterFailure = false
        app.launch()
        let toggle = app.switches["transparentToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        let original = toggle.value as? String
        defer {
            app.activate()
            if toggle.value as? String != original { toggle.tap() }
        }
        for hidden in [false, true] {
            app.activate()
            if toggle.value as? String != (hidden ? "1" : "0") { toggle.tap() }
            XCUIDevice.shared.press(.home)
            home.activate()
            try ensureHostedWidget()
            capture(hidden ? "hidden-before" : "visible-before")
            home.buttons["下一页"].firstMatch.tap()
            Thread.sleep(forTimeInterval: 3)
            capture(hidden ? "hidden-next" : "visible-next")
            home.buttons["上一页"].firstMatch.tap()
            Thread.sleep(forTimeInterval: 3)
            capture(hidden ? "hidden-previous" : "visible-previous")
        }
    }

    func testAHostedMotion() throws {
        continueAfterFailure = false
        XCUIDevice.shared.press(.home)
        home.activate()
        let cancel = home.alerts.buttons["取消"].firstMatch
        if cancel.exists { cancel.tap() }
        try ensureHostedWidget()
        let next = home.buttons["下一页"].firstMatch
        let previous = home.buttons["上一页"].firstMatch
        XCTAssertTrue(next.waitForExistence(timeout: 10), home.debugDescription)
        XCTAssertTrue(previous.exists)
        capture("motion-before")
        print("QA_TIME \(Date().timeIntervalSince1970) next-tap")
        next.tap()
        Thread.sleep(forTimeInterval: 5)
        capture("motion-next")
        print("QA_TIME \(Date().timeIntervalSince1970) previous-tap")
        previous.tap()
        Thread.sleep(forTimeInterval: 5)
        capture("motion-previous")
        print("QA_TIME \(Date().timeIntervalSince1970) triple-next-tap")
        next.tap(withNumberOfTaps: 3, numberOfTouches: 1)
        Thread.sleep(forTimeInterval: 5)
        capture("motion-rapid-next")
        XCTAssertNotEqual(app.state, .runningForeground)
    }

    func testMediumWidgetTurnsAndSharesState() throws {
        continueAfterFailure = false
        app.launch()
        let page = app.staticTexts["pageNumber"]
        XCTAssertTrue(page.waitForExistence(timeout: 10))
        let originalPage = page.label
        // Shared-state case needs two pages, using samples or five QA photos.
        XCTAssertTrue(originalPage.hasSuffix("/ 2"), "This case requires a two-page album")
        XCUIDevice.shared.press(.home)
        home.activate()

        try ensureHostedWidget()
        let next = home.buttons["下一页"].firstMatch
        let previous = home.buttons["上一页"].firstMatch
        XCTAssertTrue(next.waitForExistence(timeout: 10), home.debugDescription)
        XCTAssertTrue(previous.exists, home.debugDescription)
        XCTAssertNotEqual(app.state, .runningForeground)
        let album = home.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "翻页卡册，第")).firstMatch
        XCTAssertTrue(album.exists, home.debugDescription)
        let originalWidgetPage = album.label
        capture("springboard-before-next")
        next.tap()
        // External simctl recordVideo must be active for transition-frame evidence.
        // These assertions alone establish state changes, not animation fidelity.
        XCTAssertNotEqual(app.state, .runningForeground, "AppIntent must not open the app")
        expectation(for: NSPredicate(format: "label != %@", originalWidgetPage), evaluatedWith: album)
        waitForExpectations(timeout: 10)
        capture("springboard-after-next")
        app.activate()
        let changed = NSPredicate(format: "label != %@", originalPage)
        expectation(for: changed, evaluatedWith: page)
        waitForExpectations(timeout: 8)
        XCUIDevice.shared.press(.home)
        home.activate()
        XCTAssertTrue(locateHostedWidget(), home.debugDescription)
        XCTAssertTrue(previous.waitForExistence(timeout: 8))
        previous.tap()
        expectation(for: NSPredicate(format: "label == %@", originalWidgetPage), evaluatedWith: album)
        waitForExpectations(timeout: 10)
        capture("springboard-after-previous")
        app.activate()
        let restored = NSPredicate(format: "label == %@", originalPage)
        expectation(for: restored, evaluatedWith: page)
        waitForExpectations(timeout: 8)
    }
}
