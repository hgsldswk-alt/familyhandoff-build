import XCTest

private enum StoreLanguage: String {
    case en, hans = "zh-Hans", hant = "zh-Hant"

    var locale: String {
        switch self {
        case .en: return "en_US"
        case .hans: return "zh_CN"
        case .hant: return "zh_TW"
        }
    }
}

final class FlowUITests: XCTestCase {
    private var app: XCUIApplication!
    private var session: String!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        session = UUID().uuidString
    }

    func testTwoTapsAddAnItemAndItIsKeptAfterRelaunch() {
        launch()
        tap("group.money")
        tap("suggest.3")
        let detail = app.textViews["editor.detail"].exists ? app.textViews["editor.detail"] : app.textFields["editor.detail"]
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
        detail.typeText("Policy in the safe")
        tap("editor.save")
        XCTAssertTrue(element("entry.1").waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Policy in the safe"].exists)
        app.terminate()
        launch(reset: false)
        XCTAssertTrue(app.staticTexts["Items written: 1"].waitForExistence(timeout: 5))
    }

    func testHandoffShowsPdfAndPasscode() {
        launch(seed: true)
        tap("home.handoff")
        XCTAssertTrue(app.buttons["handoff.pdf"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["handoff.code"].waitForExistence(timeout: 10))
        let code = app.staticTexts["handoff.passcode"]
        XCTAssertTrue(code.exists)
        XCTAssertEqual(code.label.count, 9)
        tap("handoff.close", down: false)
        XCTAssertTrue(app.buttons["home.handoff"].waitForExistence(timeout: 5))
    }

    func testFillingEveryAreaShowsTheMilestoneCard() {
        launch(seed: true)
        tap("group.home")
        tap("suggest.1")
        let detail = app.textViews["editor.detail"].exists ? app.textViews["editor.detail"] : app.textFields["editor.detail"]
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
        detail.typeText("Feed Momo twice a day")
        tap("editor.save")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(element("done.card").waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["done.share"].exists)
        tap("done.close", down: false)
        XCTAssertTrue(app.buttons["home.handoff"].waitForExistence(timeout: 5))
    }

    func testSettingsOffersImportAndPrivacy() {
        launch()
        tap("home.settings", down: false)
        XCTAssertTrue(app.buttons["settings.import"].waitForExistence(timeout: 5))
        tap("settings.import")
        XCTAssertTrue(app.textFields["import.passcode"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["import.open"].isEnabled)
    }

    func testStoreEnglish() throws { try captureStore(.en) }
    func testStoreSimplifiedChinese() throws { try captureStore(.hans) }
    func testStoreTraditionalChinese() throws { try captureStore(.hant) }

    private func captureStore(_ language: StoreLanguage) throws {
        launch(language: language, seed: true)
        try shot("01-home", language)
        tap("group.money")
        XCTAssertTrue(element("entry.1").waitForExistence(timeout: 5))
        try shot("02-group", language)
        tap("entry.1")
        XCTAssertTrue(app.buttons["editor.save"].waitForExistence(timeout: 5))
        try shot("03-entry", language)
        tap("editor.save")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        tap("home.handoff")
        XCTAssertTrue(app.buttons["handoff.pdf"].waitForExistence(timeout: 10))
        try shot("04-handoff", language)
        tap("handoff.close", down: false)
        tap("group.home")
        tap("suggest.1")
        let detail = app.textViews["editor.detail"].exists ? app.textViews["editor.detail"] : app.textFields["editor.detail"]
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
        detail.typeText(language == .en ? "Feed Momo twice a day" : "Momo 每天喂两次")
        tap("editor.save")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(element("done.card").waitForExistence(timeout: 10))
        try shot("05-done", language)
    }

    private func launch(reset: Bool = true, language: StoreLanguage = .en, seed: Bool = false) {
        app.launchArguments = ["-ui-testing", "-AppleLanguages", "(\(language.rawValue))",
                               "-AppleLocale", language.locale] + (reset ? ["-reset"] : []) + (seed ? ["-seed"] : [])
        app.launchEnvironment = ["FAMILYHANDOFF_TEST_SESSION": session]
        app.launch()
        XCTAssertTrue(element("home.progress").waitForExistence(timeout: 10))
    }

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func visible(_ element: XCUIElement, down: Bool = true) -> Bool {
        for attempt in 0...6 {
            if element.exists && element.isHittable { return true }
            if attempt < 6 {
                if down { app.swipeUp() } else { app.swipeDown() }
            }
        }
        return false
    }

    private func tap(_ id: String, down: Bool = true, file: StaticString = #filePath, line: UInt = #line) {
        let target = app.buttons[id].exists ? app.buttons[id] : element(id)
        XCTAssertTrue(target.waitForExistence(timeout: 5), id, file: file, line: line)
        XCTAssertTrue(visible(target, down: down), id, file: file, line: line)
        target.tap()
    }

    private func shot(_ scene: String, _ language: StoreLanguage) throws {
        let name = "store-\(language.rawValue)-\(scene)"
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        let environment = ProcessInfo.processInfo.environment
        if let path = environment["SHOTS_DIR"] ?? environment["TEST_RUNNER_SHOTS_DIR"] {
            let directory = URL(fileURLWithPath: path, isDirectory: true)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try? screenshot.pngRepresentation.write(to: directory.appendingPathComponent(name + ".png"))
        }
    }
}
