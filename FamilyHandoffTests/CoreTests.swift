import XCTest

final class CoreTests: XCTestCase {
    func testAddRejectsBlankAndDuplicatesInSameArea() {
        var list = HandoffList()
        XCTAssertNotNil(list.add("Mortgage", to: .money))
        XCTAssertNil(list.add("  mortgage ", to: .money))
        XCTAssertNil(list.add("   ", to: .money))
        XCTAssertNotNil(list.add("Mortgage", to: .documents))
        XCTAssertEqual(list.entries.count, 2)
    }

    func testProgressCountsOnlyFilledItemsUpToGoal() {
        var list = HandoffList()
        list.add("A", to: .money, detail: "drawer")
        list.add("B", to: .money)
        XCTAssertEqual(list.filledCount(in: .money), 1)
        XCTAssertEqual(list.progress(in: .money), 1.0 / 3.0, accuracy: 0.0001)
        list.add("C", to: .money, detail: "x")
        list.add("D", to: .money, detail: "x")
        list.add("E", to: .money, detail: "x")
        XCTAssertEqual(list.progress(in: .money), 1.0, accuracy: 0.0001)
        XCTAssertEqual(list.progress, 1.0 / 6.0, accuracy: 0.0001)
        XCTAssertFalse(list.everyGroupStarted)
        for area in Area.allCases { list.add("Z", to: area, detail: "y") }
        XCTAssertTrue(list.everyGroupStarted)
    }

    func testUpdateKeepsIdentityAndIgnoresBlankTitle() {
        var list = HandoffList()
        var entry = list.add("Will", to: .documents)!
        entry.detail = "Safe, 2nd shelf"
        list.update(entry)
        XCTAssertEqual(list.entries.first?.detail, "Safe, 2nd shelf")
        entry.title = "  "
        entry.detail = "changed"
        list.update(entry)
        XCTAssertEqual(list.entries.first?.detail, "Safe, 2nd shelf")
        list.remove(entry.id)
        XCTAssertTrue(list.entries.isEmpty)
    }

    func testMergeKeepsNewerCopyAndAddsNewItems() {
        let old = Date(timeIntervalSince1970: 1_000)
        let new = Date(timeIntervalSince1970: 2_000)
        var mine = HandoffList()
        mine.add("Will", to: .documents, detail: "old place", at: old)
        var theirs = HandoffList()
        theirs.add("will", to: .documents, detail: "new place", at: new)
        theirs.add("Lawyer", to: .contacts, detail: "Kim", at: new)
        mine.merge(theirs)
        XCTAssertEqual(mine.entries.count, 2)
        XCTAssertEqual(mine.entries(in: .documents).first?.detail, "new place")
        XCTAssertEqual(mine.updated, new)
        var stale = HandoffList()
        stale.add("Will", to: .documents, detail: "stale", at: old)
        mine.merge(stale)
        XCTAssertEqual(mine.entries(in: .documents).first?.detail, "new place")
    }

    func testReviewDateIsSixMonthsAfterLastEdit() {
        var list = HandoffList()
        XCTAssertNil(list.reviewDate())
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let date = calendar.date(from: DateComponents(year: 2026, month: 1, day: 31))!
        list.add("A", to: .home, at: date)
        let review = list.reviewDate(calendar: calendar)!
        XCTAssertEqual(calendar.dateComponents([.year, .month], from: review), DateComponents(year: 2026, month: 7))
    }

    func testTransferRoundTripWithPasscode() throws {
        var list = HandoffList()
        list.add("Main bank", to: .money, detail: "Chase · 招商银行 · \"quoted\"")
        list.add("Pet care", to: .home, detail: "Feed twice a day")
        let passcode = Transfer.newPasscode()
        XCTAssertEqual(passcode.count, 9)
        XCTAssertEqual(Transfer.normalize(passcode).count, 8)
        let sealed = try Transfer.seal(list, passcode: passcode)
        XCTAssertTrue(sealed.hasPrefix(Transfer.prefix))
        XCTAssertFalse(sealed.contains("Chase"))
        let opened = try Transfer.open("Here you go:\n" + sealed + "\n", passcode: passcode.lowercased())
        XCTAssertEqual(opened.entries.map(\.title), list.entries.map(\.title))
        XCTAssertEqual(opened.entries.map(\.detail), list.entries.map(\.detail))
    }

    func testTransferRejectsWrongPasscodeAndGarbage() throws {
        let sealed = try Transfer.seal(HandoffList(), passcode: "ABCD-2345")
        XCTAssertThrowsError(try Transfer.open(sealed, passcode: "ABCD-2346")) {
            XCTAssertEqual($0 as? Transfer.Failure, .wrongPasscode)
        }
        XCTAssertThrowsError(try Transfer.open("hello", passcode: "ABCD-2345")) {
            XCTAssertEqual($0 as? Transfer.Failure, .notAHandoff)
        }
        XCTAssertThrowsError(try Transfer.open(Transfer.prefix + "!!!", passcode: "ABCD-2345")) {
            XCTAssertEqual($0 as? Transfer.Failure, .damaged)
        }
        XCTAssertFalse(Transfer.looksLikeHandoff(nil))
    }

    func testEveryAreaHasLocalizedSuggestionsInAllLanguages() throws {
        for language in ["en", "zh-Hans", "zh-Hant"] {
            let path = try XCTUnwrap(L.bundle.path(forResource: language, ofType: "lproj"), language)
            let bundle = try XCTUnwrap(Bundle(path: path))
            for area in Area.allCases {
                XCTAssertNotEqual(L.t(area.titleKey, bundle: bundle), area.titleKey, language)
                for key in area.suggestionKeys {
                    XCTAssertNotEqual(L.t(key, bundle: bundle), key, "\(language) \(key)")
                }
            }
        }
    }

    func testStoreRoundTrip() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        let store = Store(url: url)
        var list = HandoffList()
        list.add("Will", to: .documents, detail: "Safe")
        store.save(list)
        XCTAssertEqual(store.load().entries.map(\.title), ["Will"])
        try? FileManager.default.removeItem(at: url)
    }
}
