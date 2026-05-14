import XCTest
@testable import AutoChoice

// MARK: - WheelStore.spin() Regression Suite
//
// Context (CLAUDE.md §15d, round-5 reject 2026-05-11):
//   Swift's truncatingRemainder(dividingBy:) preserves the sign of the dividend.
//   The pre-fix spin() formula used truncatingRemainder to derive the next
//   currentRotation, which caused sub-segment drift after multiple spins when
//   currentRotation became negative. Reviewer observed: pointer on item A,
//   result label said item B — 2.1(a) reject.
//
//   Fix in WheelStore.spin(): floor-divide anchor
//     let currentLap = (currentRotation / 360).rounded(.down)
//     currentRotation = (currentLap - Double(rounds)) * 360 + target
//   guarantees (currentRotation mod 360) == (target mod 360) regardless of sign.
//
// These tests exercise the public spin() API directly and assert the invariant
// that holds after every spin — they do NOT depend on internal formula details.

final class WheelStoreSpinTests: XCTestCase {

    // MARK: - Helpers

    /// Euclidean modulo — always returns a value in [0, b).
    private func euclidMod(_ a: Double, _ b: Double) -> Double {
        let r = a.truncatingRemainder(dividingBy: b)
        return r >= 0 ? r : r + b
    }

    /// Build a WheelStore with a deterministic N-choice list active.
    private func storeWithChoices(_ n: Int) -> (WheelStore, ChoiceList) {
        let store = WheelStore()
        let choices = (0..<n).map { Choice(label: "C\($0)") }
        let list = ChoiceList(name: "Spin fixture", choices: choices)
        store.lists.append(list)
        store.setActive(list)
        return (store, list)
    }

    // MARK: - Tests

    /// CLAUDE.md §15d防回归: 10 random spins → final rotation mod 360 must match
    /// the expected target slot for lastResult.  Fails on the pre-fix formula.
    func testSpinModularAlignmentAfterConsecutiveSpins() {
        let (store, list) = storeWithChoices(6)
        guard list.choices.count >= 2 else {
            XCTFail("Fixture list must have >= 2 choices")
            return
        }
        let segment = 360.0 / Double(list.choices.count)

        for _ in 0..<10 {
            let result = store.spin()
            guard let chosen = result,
                  let idx = list.choices.firstIndex(of: chosen) else {
                XCTFail("spin() must return a choice present in the active list")
                return
            }
            let target = -(Double(idx) * segment + segment / 2)
            let actualMod   = euclidMod(store.currentRotation, 360)
            let expectedMod = euclidMod(target, 360)
            XCTAssertEqual(
                actualMod,
                expectedMod,
                accuracy: 0.001,
                "Spin \(idx): currentRotation mod 360 (\(actualMod)) must equal target mod 360 (\(expectedMod)) — round-5 reject防回归"
            )
        }
    }

    /// Regression for negative accumulator: seed currentRotation to a large
    /// negative value (simulates many spins rolling back) then verify the
    /// invariant still holds.  The pre-fix formula broke here because
    ///   (-2310).truncatingRemainder(dividingBy: 360) == -150  (not 210)
    func testSpinHandlesNegativeRotationAccumulator() {
        let (store, list) = storeWithChoices(6)
        guard list.choices.count >= 2 else {
            XCTFail("Fixture list must have >= 2 choices")
            return
        }
        let segment = 360.0 / Double(list.choices.count)

        // Simulate multiple-spin accumulation in the negative direction.
        store.currentRotation = -2310
        // Run 10 more spins from the negative starting point.
        for _ in 0..<10 {
            let result = store.spin()
            guard let chosen = result,
                  let idx = list.choices.firstIndex(of: chosen) else {
                XCTFail("spin() must return a choice present in the active list")
                return
            }
            let target = -(Double(idx) * segment + segment / 2)
            let actualMod   = euclidMod(store.currentRotation, 360)
            let expectedMod = euclidMod(target, 360)
            XCTAssertEqual(
                actualMod,
                expectedMod,
                accuracy: 0.001,
                "Negative accumulator spin: actualMod (\(actualMod)) must equal expectedMod (\(expectedMod))"
            )
        }
    }

    /// Stress: 25 consecutive spins on an 8-choice wheel (at free-tier boundary).
    /// Exercises the exact scenario a reviewer triggers — filling a list to the
    /// limit and spinning repeatedly.
    func testSpinAlignmentStress25Spins8Choices() {
        let (store, list) = storeWithChoices(8)
        guard list.choices.count >= 2 else {
            XCTFail("Fixture list must have >= 2 choices")
            return
        }
        let segment = 360.0 / Double(list.choices.count)

        for spinNumber in 1...25 {
            let result = store.spin()
            guard let chosen = result,
                  let idx = list.choices.firstIndex(of: chosen) else {
                XCTFail("spin #\(spinNumber): no valid lastResult")
                return
            }
            let target      = -(Double(idx) * segment + segment / 2)
            let actualMod   = euclidMod(store.currentRotation, 360)
            let expectedMod = euclidMod(target, 360)
            XCTAssertEqual(
                actualMod,
                expectedMod,
                accuracy: 0.001,
                "Spin #\(spinNumber): pointer drift detected (actualMod=\(actualMod), expectedMod=\(expectedMod))"
            )
        }
    }

    /// Validate that spin() returns a Choice whose label is present in the active
    /// list — guards against randomElement() returning a stale reference.
    func testSpinResultAlwaysInActiveList() {
        let (store, list) = storeWithChoices(6)
        let labels = Set(list.choices.map(\.label))
        for _ in 0..<20 {
            let result = store.spin()
            XCTAssertNotNil(result, "spin() must not return nil for a non-empty list")
            if let result {
                XCTAssertTrue(labels.contains(result.label),
                              "Returned label '\(result.label)' not found in active list choices")
            }
        }
    }
}
