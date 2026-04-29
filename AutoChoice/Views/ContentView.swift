import SwiftUI

struct ContentView: View {
    @Environment(WheelStore.self) private var store
    @Environment(IAPManager.self) private var iap

    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false

    @State private var showPaywall = false
    @State private var showLists = false
    @State private var showSettings = false
    @State private var showHistory = false
    @State private var resultBump = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                resultBanner

                Spacer(minLength: 8)

                WheelView(
                    choices: store.activeList?.choices ?? [],
                    rotation: store.currentRotation,
                    palette: WheelTheme.by(id: store.selectedThemeID).palette
                )
                .frame(maxWidth: 360)
                .aspectRatio(1, contentMode: .fit)
                .padding(.horizontal)
                .animation(.spring(response: 3.5, dampingFraction: 0.85), value: store.currentRotation)

                Spacer(minLength: 8)

                spinButton
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
            .padding(.top)
            .navigationTitle(store.activeList?.name ?? "AutoChoice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .sheet(isPresented: $showLists) { ChoiceListView() }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showHistory) { HistoryView() }
            .fullScreenCover(isPresented: Binding(
                get: { !hasSeenOnboarding },
                set: { _ in /* OnboardingView writes hasSeenOnboarding directly */ }
            )) {
                OnboardingView(hasSeenOnboarding: $hasSeenOnboarding)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button { showLists = true } label: {
                Image(systemName: "list.bullet.rectangle")
            }
            .accessibilityLabel("Lists")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button { showHistory = true } label: { Label("History", systemImage: "clock.arrow.circlepath") }
                Button { showSettings = true } label: { Label("Settings", systemImage: "gear") }
                if !iap.isPremium {
                    Button { showPaywall = true } label: { Label("Go Premium", systemImage: "sparkles") }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    @ViewBuilder
    private var resultBanner: some View {
        if let result = store.lastResult, !store.isSpinning {
            HStack(spacing: 8) {
                Text(result.label)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                shareButton(for: result.label)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .id(resultBump)
            .transition(.scale.combined(with: .opacity))
        } else {
            Color.clear.frame(height: 56)
        }
    }

    @ViewBuilder
    private func shareButton(for resultLabel: String) -> some View {
        if iap.isPremium, let listName = store.activeList?.name {
            let palette = WheelTheme.by(id: store.selectedThemeID).palette
            if let cardURL = ShareCardRenderer.renderToTempURL(result: resultLabel, listName: listName, palette: palette) {
                ShareLink(item: cardURL) {
                    Image(systemName: "square.and.arrow.up").font(.title3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Share result")
            }
        }
    }

    private var spinButton: some View {
        Button(action: handleSpin) {
            Text(store.isSpinning ? "Spinning…" : "Spin")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(spinButtonBackground, in: RoundedRectangle(cornerRadius: 18))
                .foregroundStyle(.white)
        }
        .disabled(store.isSpinning || (store.activeList?.choices.isEmpty ?? true))
    }

    private var spinButtonBackground: Color {
        (store.activeList?.choices.isEmpty ?? true) ? .gray : .accentColor
    }

    private func handleSpin() {
        guard !store.isSpinning, let list = store.activeList, !list.choices.isEmpty else { return }
        if list.choices.count > WheelStore.freeChoiceLimit, !iap.isPremium {
            Haptics.warning()
            showPaywall = true
            return
        }
        Haptics.medium()
        store.isSpinning = true
        store.spin()
        Task {
            try? await Task.sleep(for: .seconds(3.5))
            await MainActor.run {
                store.isSpinning = false
                resultBump += 1
                Haptics.success()
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(WheelStore())
        .environment(IAPManager())
}
