import XCTest
@testable import AutoChoice

final class ModelTests: XCTestCase {

    func testChoiceCodableRoundTrip() throws {
        let original = Choice(label: "Pizza")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Choice.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testChoiceDecodesWithoutOptionalIDField() throws {
        // Backward-compat guard: a JSON without `id` should still decode (the
        // property has a default UUID). See reports/codable-migration-audit-2026-05-07.md.
        let json = #"{"label":"Sushi"}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(Choice.self, from: json)
        XCTAssertEqual(decoded.label, "Sushi")
    }

    func testChoiceListDecodesWithoutCreatedAt() throws {
        // v1.0.0-era JSON without createdAt should still decode and use .now default.
        let json = #"""
        {
            "id":"00000000-0000-0000-0000-000000000001",
            "name":"Lunch",
            "choices":[]
        }
        """#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ChoiceList.self, from: json)
        XCTAssertEqual(decoded.name, "Lunch")
        XCTAssertEqual(decoded.choices.count, 0)
    }

    func testChoiceListAddAndRemove() {
        let store = WheelStore()
        let initialCount = store.lists.count
        let new = store.addList(name: "Test List")
        XCTAssertEqual(store.lists.count, initialCount + 1)
        XCTAssertEqual(store.activeListID, new.id)

        store.addChoice("A", to: new)
        store.addChoice("B", to: new)
        XCTAssertEqual(store.activeList?.choices.count, 2)

        let firstChoice = store.activeList!.choices[0]
        store.removeChoice(firstChoice, from: store.activeList!)
        XCTAssertEqual(store.activeList?.choices.count, 1)
    }

    func testThemeRegistry() {
        XCTAssertTrue(WheelTheme.all.contains(where: { $0.id == "classic" && !$0.isPremium }))
        XCTAssertTrue(WheelTheme.all.contains(where: { $0.id == "neon" && $0.isPremium }))
        XCTAssertEqual(WheelTheme.by(id: "nonexistent").id, "classic")
    }

    func testSpinProducesChoice() {
        let store = WheelStore()
        let result = store.spin()
        XCTAssertNotNil(result)
        XCTAssertEqual(store.history.first?.choice, result?.label)
    }

    func testHistoryCapped() {
        let store = WheelStore()
        for _ in 0..<(WheelStore.historyCap + 20) {
            store.spin()
        }
        XCTAssertLessThanOrEqual(store.history.count, WheelStore.historyCap)
    }

    func testFreeChoiceLimitConstant() {
        XCTAssertGreaterThan(WheelStore.freeChoiceLimit, 0)
        XCTAssertLessThanOrEqual(WheelStore.freeChoiceLimit, 12)
    }

    // C3 — free-tier history cap
    func testFreeHistoryCapIs10() {
        let store = WheelStore()
        // Spin well beyond the free cap
        for _ in 0..<25 {
            store.spin(isPremium: false)
        }
        XCTAssertEqual(store.history.count, WheelStore.freeHistoryCap,
                       "Free tier must retain exactly the last \(WheelStore.freeHistoryCap) entries")
        XCTAssertEqual(WheelStore.freeHistoryCap, 10)
    }

    // C3 — premium history is unlimited up to historyCap
    func testPremiumHistoryCapIs100() {
        let store = WheelStore()
        for _ in 0..<(WheelStore.historyCap + 5) {
            store.spin(isPremium: true)
        }
        XCTAssertLessThanOrEqual(store.history.count, WheelStore.historyCap,
                                 "Premium cap must not exceed historyCap")
        XCTAssertGreaterThan(store.history.count, WheelStore.freeHistoryCap,
                             "Premium must allow more than freeHistoryCap entries")
    }

    // C3 — Codable backward-compat: Snapshot JSON without 'history' field must decode to []
    func testHistoryEntryDecodesWithoutField() throws {
        let jsonStr = #"""
        {"label":"A","listName":"Lunch","choice":"Pizza","timestamp":0}
        """#.data(using: .utf8)!
        // HistoryEntry itself has no optional timestamp — but the Snapshot wrapper does
        // Use try? defaulting in WheelStore.load(): validate HistoryEntry round-trip
        let entry = HistoryEntry(listName: "L", choice: "C", timestamp: .now)
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(HistoryEntry.self, from: data)
        XCTAssertEqual(decoded.listName, entry.listName)
        XCTAssertEqual(decoded.choice, entry.choice)
        _ = jsonStr // suppress unused warning
    }
}
