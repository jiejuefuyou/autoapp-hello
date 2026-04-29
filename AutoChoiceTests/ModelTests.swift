import XCTest
@testable import AutoChoice

final class ModelTests: XCTestCase {

    func testChoiceCodableRoundTrip() throws {
        let original = Choice(label: "Pizza")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Choice.self, from: data)
        XCTAssertEqual(decoded, original)
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
}
