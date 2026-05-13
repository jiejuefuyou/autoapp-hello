import Foundation
import SwiftUI

/// Centralized language override for the in-app language picker.
///
/// SwiftUI applies the chosen locale immediately via `.environment(\.locale, ...)`.
/// `AppleLanguages` is also written so any UIKit-bridged code (alerts, system pickers)
/// uses the same language on the *next* launch.
@Observable
final class LocalizationManager {

    static let shared = LocalizationManager()

    /// Supported BCP-47 codes shipped with the app, in display order.
    static let supportedLanguages: [String] = [
        "en", "ja", "zh-Hans", "zh-Hant", "ko", "es", "fr", "de"
    ]

    /// Empty string ("") means "follow system default".
    private let storageKey = "appLanguageOverride"

    /// Current override; "" follows system.
    var override: String {
        didSet { persist() }
    }

    /// The `Locale` that should be passed into `.environment(\.locale, ...)`.
    var currentLocale: Locale {
        if override.isEmpty {
            return .current
        }
        return Locale(identifier: override)
    }

    private init() {
        self.override = UserDefaults.standard.string(forKey: storageKey) ?? ""
        // Reapply persisted override to AppleLanguages on launch so UIKit-side
        // strings (system alerts, share sheet titles) match.
        applyAppleLanguages(override)
    }

    /// Sets a new override. Pass "" to revert to system default.
    func setOverride(_ code: String) {
        let normalized = Self.supportedLanguages.contains(code) ? code : ""
        override = normalized
        applyAppleLanguages(normalized)
    }

    private func persist() {
        UserDefaults.standard.set(override, forKey: storageKey)
    }

    /// Writes (or clears) the AppleLanguages preference. iOS reads this on
    /// next launch for UIKit-side localization. SwiftUI uses `currentLocale`
    /// in-process so the change is immediate within the running app.
    private func applyAppleLanguages(_ code: String) {
        let defaults = UserDefaults.standard
        if code.isEmpty {
            defaults.removeObject(forKey: "AppleLanguages")
        } else {
            defaults.set([code], forKey: "AppleLanguages")
        }
    }

    /// Native-script display names. Hardcoded because Apple's
    /// `localizedString(forLanguageCode:)` drops the script tag and collapses
    /// "zh-Hans" + "zh-Hant" into a single "中文" label, which makes the two
    /// Chinese options indistinguishable in the picker (user report 2026-05-13).
    static let displayNames: [String: String] = [
        "en":      "English",
        "ja":      "日本語",
        "ko":      "한국어",
        "zh-Hans": "简体中文",
        "zh-Hant": "繁體中文",
        "es":      "Español",
        "fr":      "Français",
        "de":      "Deutsch",
    ]

    /// Display name for a language code, rendered in that language's own script.
    static func displayName(for code: String) -> String {
        if code.isEmpty {
            return String(localized: "System default")
        }
        if let native = displayNames[code] {
            return native
        }
        let locale = Locale(identifier: code)
        return locale.localizedString(forIdentifier: code)
            ?? Locale.current.localizedString(forIdentifier: code)
            ?? code
    }
}
