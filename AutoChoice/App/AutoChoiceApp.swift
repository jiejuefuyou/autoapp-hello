import SwiftUI

@main
struct AutoChoiceApp: App {
    @State private var store = WheelStore()
    @State private var iap = IAPManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(iap)
                .task { await iap.refresh() }
                .tint(.accentColor)
        }
    }
}
