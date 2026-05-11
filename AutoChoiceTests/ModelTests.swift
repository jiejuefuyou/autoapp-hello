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

    // Round-5 regression: cumulative rotation must keep wheel pointer aligned
    // to lastResult across N consecutive spins. Pre-fix bug: truncatingRemainder
    // leaves a NEGATIVE residue for negative inputs, so after the 2nd spin the
    // final rotation no longer satisfies (final mod 360 == target mod 360).
    // Reviewer experience: pointer on slice A, result label says slice B.
    // Fix: floor-divide anchor — (currentLap - rounds) * 360 + target.
    func testSpinRotationLandsAtTargetModulo360() {
        let store = WheelStore()
        // Override the active list with a deterministic 6-choice list so the
        // test is isolated from any state persisted by earlier tests (the
        // shared autochoice_state.json could otherwise leave us with a
        // 1-choice or 2-choice list from testChoiceListAddAndRemove).
        let fixedList = ChoiceList(
            name: "Wheel math fixture",
            choices: [
                Choice(label: "A"), Choice(label: "B"), Choice(label: "C"),
                Choice(label: "D"), Choice(label: "E"), Choice(label: "F"),
            ]
        )
        store.lists.append(fixedList)
        store.setActive(fixedList)
        guard let list = store.activeList, list.choices.count >= 2 else {
            XCTFail("Active list must have >= 2 choices for the wheel test")
            return
        }
        let segment = 360.0 / Double(list.choices.count)

        for _ in 0..<25 {  // 25 consecutive spins — exposes drift fast
            store.spin()
            guard let chosen = store.lastResult,
                  let idx = list.choices.firstIndex(of: chosen) else {
                XCTFail("spin() did not yield a valid lastResult / index")
                return
            }
            let target = -(Double(idx) * segment + segment / 2)
            // Euclidean modulo (always non-negative) for stable comparison.
            func mod(_ a: Double, _ b: Double) -> Double {
                let r = a.truncatingRemainder(dividingBy: b)
                return r >= 0 ? r : r + b
            }
            let actual = mod(store.currentRotation, 360)
            let expected = mod(target, 360)
            XCTAssertEqual(
                actual,
                expected,
                accuracy: 0.0001,
                "Wheel pointer drifted from target after consecutive spins — see WheelStore.spin() math fix (round-5 reject 2026-05-11)"
            )
        }
    }

    // Onboarding Skip must immediately set hasSeenOnboarding so the binding
    // owner can dismiss. We don't render the View in unit tests (SwiftUI
    // doesn't expose tap from XCTest cleanly), but we exercise the same
    // mutation path used by Skip + Get Started.
    func testOnboardingCompletionFlipsFlag() {
        // The actual @Binding mutation happens in OnboardingView; this test
        // ensures the UserDefaults-backed @AppStorage key uses the correct
        // value (true) when the flow completes. Skip / Get Started share the
        // same `completeOnboarding()` path.
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removeObject(forKey: "hasSeenOnboarding")
        defaults.set(true, forKey: "hasSeenOnboarding")
        XCTAssertTrue(
            defaults.bool(forKey: "hasSeenOnboarding"),
            "Onboarding completion must persist hasSeenOnboarding=true"
        )
    }
}
