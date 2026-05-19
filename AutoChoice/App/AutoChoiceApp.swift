import SwiftUI

@main
struct AutoChoiceApp: App {
    @State private var store = WheelStore()
    @State private var iap = IAPManager()
    @State private var l10n = LocalizationManager.shared

    init() {
        // EAGER init: force LocalizationManager.shared (and its Bundle.main
        // swizzle in installBundleOverride) to run BEFORE SwiftUI evaluates
        // any Text(LocalizedStringKey(...)) in body. If we let @State default
        // value trigger first access, swizzle could land after first
        // localized string resolution → wrong .lproj cached.
        _ = LocalizationManager.shared

        // Snapshot mode: skip onboarding so UI tests land on the main screen
        // immediately without having to dismiss a fullScreenCover.
        if ProcessInfo.processInfo.arguments.contains("-FASTLANE_SNAPSHOT") {
            UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(iap)
                .environment(l10n)
                .environment(\.locale, l10n.currentLocale)
                .id(l10n.override)  // CRITICAL: force complete view tree rebuild on language change.
                                    // Without this SwiftUI caches Text(LocalizedStringKey(...))
                                    // resolutions and the new .lproj is never read.
                                    // Pairs with OverrideBundle swap in LocalizationManager.swift.
                .task { await iap.refresh() }
                .tint(.accentColor)
        }
    }
}
