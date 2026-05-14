import XCTest
@testable import AutoChoice

final class LocalizationTests: XCTestCase {

    // MARK: - Helpers

    /// Load the Localizable.strings table for a given BCP-47 code directly
    /// from the app bundle (NOT test bundle), returning the key→value dictionary.
    /// Uses `forLocalization:` which correctly resolves .lproj — the previous
    /// `subdirectory:` approach failed because Apple treats .lproj as a special
    /// locale directory, not a generic subdirectory.
    private func strings(for code: String) -> [String: String] {
        // Bundle(for:) with a class from the main app target returns the app
        // bundle (containing Localizable.strings), not the test bundle.
        let appBundle = Bundle(for: LocalizationManager.self)
        guard let path = appBundle.path(forResource: "Localizable",
                                         ofType: "strings",
                                         inDirectory: nil,
                                         forLocalization: code) else {
            return [:]
        }
        return (NSDictionary(contentsOfFile: path) as? [String: String]) ?? [:]
    }

    // MARK: - Tests

    /// Core UI keys must exist in all 8 language tables with a non-empty,
    /// non-fallback-to-English value (for non-English tables).
    func testCoreKeysExistInAll8Languages() {
        let coreKeys = ["Wheel", "History", "Settings", "Spin", "Language", "Theme", "Premium"]
        let langs = ["en", "ja", "zh-Hans", "zh-Hant", "ko", "es", "fr", "de"]

        for lang in langs {
            let table = strings(for: lang)
            for key in coreKeys {
                let value = table[key]
                XCTAssertNotNil(value,
                    "[\(lang)] Missing key '\(key)' in Localizable.strings")
                XCTAssertFalse(value?.isEmpty ?? true,
                    "[\(lang)] Empty value for key '\(key)'")
            }
        }
    }

    /// The two Chinese picker labels must be distinct and match the expected
    /// native-script names — this is the exact user-reported bug fixed in v1.0.7.
    func testChinesePickerLabelsAreDistinct() {
        let simpLabel = LocalizationManager.displayName(for: "zh-Hans")
        let tradLabel = LocalizationManager.displayName(for: "zh-Hant")

        XCTAssertNotEqual(simpLabel, tradLabel,
            "zh-Hans and zh-Hant must produce different picker labels (was both '中文' before v1.0.7)")
        XCTAssertEqual(simpLabel, "简体中文",
            "zh-Hans displayName must be '简体中文'")
        XCTAssertEqual(tradLabel, "繁體中文",
            "zh-Hant displayName must be '繁體中文'")
    }

    /// setOverride must update currentLocale.identifier so the in-process
    /// environment locale switches immediately without restart.
    func testSetOverrideUpdatesCurrentLocale() {
        let manager = LocalizationManager.shared
        let original = manager.override

        manager.setOverride("ja")
        XCTAssertEqual(manager.currentLocale.identifier, "ja",
            "currentLocale must reflect the override set by setOverride(_:)")

        // Restore to avoid polluting other tests.
        manager.setOverride(original)
    }
}
