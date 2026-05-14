import SwiftUI

@main
struct AutoChoiceApp: App {
    @State private var store = WheelStore()
    @State private var iap = IAPManager()
    @State private var l10n = LocalizationManager.shared
    /// Toast message shown after a shared-wheel import via deep link / Universal Link.
    @State private var importToast: String?

    init() {
        // Snapshot mode: skip onboarding so UI tests land on the main screen
        // immediately without having to dismiss a fullScreenCover.
        if ProcessInfo.processInfo.arguments.contains("-FASTLANE_SNAPSHOT") {
            UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(importToast: $importToast)
                .environment(store)
                .environment(iap)
                .environment(l10n)
                .environment(\.locale, l10n.currentLocale)
                .task { await iap.refresh() }
                .tint(.accentColor)
                .onOpenURL { url in
                    guard let dto = WheelShareService.decodeURL(url) else { return }
                    let message = store.importSharedWheel(dto, isPremium: iap.isPremium)
                    importToast = message
                }
        }
    }
}
