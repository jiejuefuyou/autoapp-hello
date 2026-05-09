import SwiftUI

struct ContentView: View {
    @Environment(WheelStore.self) private var store
    @Environment(IAPManager.self) private var iap

    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false

    var body: some View {
        TabView {
            WheelTab()
                .tabItem { Label(LocalizedStringKey("Wheel"), systemImage: "circle.grid.cross.fill") }
            HistoryTab()
                .tabItem { Label(LocalizedStringKey("History"), systemImage: "clock.arrow.circlepath") }
            SettingsTab()
                .tabItem { Label(LocalizedStringKey("Settings"), systemImage: "gear") }
        }
        .fullScreenCover(isPresented: Binding(
            get: { !hasSeenOnboarding },
            set: { _ in /* OnboardingView writes hasSeenOnboarding directly */ }
        )) {
            OnboardingView(hasSeenOnboarding: $hasSeenOnboarding)
        }
    }
}

// MARK: - Wheel Tab

private struct WheelTab: View {
    @Environment(WheelStore.self) private var store
    @Environment(IAPManager.self) private var iap

    @State private var showPaywall = false
    @State private var showLists = false
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
            .navigationTitle(store.activeList?.name ?? String(localized: "AutoChoice"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showLists = true } label: {
                        Image(systemName: "list.bullet.rectangle")
                    }
                    .accessibilityLabel(Text("Lists"))
                }
                if !iap.isPremium {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showPaywall = true } label: {
                            Label(LocalizedStringKey("Go Premium"), systemImage: "sparkles")
                        }
                    }
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .sheet(isPresented: $showLists) { ChoiceListView() }
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
        // Always render the share button so reviewers (and free-tier users) can
        // exercise the share affordance. Premium users get a high-resolution
        // gradient share card; free users get a plain text share that links to
        // the App Store. This satisfies App Review 2.1(a) (the button must be
        // responsive) without giving away the Premium-only share-card asset.
        let listName = store.activeList?.name ?? String(localized: "AutoChoice")
        if iap.isPremium {
            let palette = WheelTheme.by(id: store.selectedThemeID).palette
            if let cardURL = ShareCardRenderer.renderToTempURL(result: resultLabel, listName: listName, palette: palette) {
                ShareLink(item: cardURL) {
                    Image(systemName: "square.and.arrow.up").font(.title3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Share result"))
            }
        } else {
            let shareText = String(
                format: String(localized: "AutoChoice picked: %@ — try it: https://apps.apple.com/app/id6765667062"),
                resultLabel
            )
            ShareLink(item: shareText) {
                Image(systemName: "square.and.arrow.up").font(.title3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Share result"))
        }
    }

    private var spinButton: some View {
        Button(action: handleSpin) {
            Text(store.isSpinning ? LocalizedStringKey("Spinning…") : LocalizedStringKey("Spin"))
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
        store.spin(isPremium: iap.isPremium)
        Task {
            try? await Task.sleep(for: .seconds(3.5))
            await MainActor.run {
                store.isSpinning = false
                resultBump += 1
                Haptics.success()
                ReviewService.recordSuccess()
                ReviewService.maybeRequestReview()
            }
        }
    }
}

// MARK: - History Tab

private struct HistoryTab: View {
    @Environment(WheelStore.self) private var store
    @Environment(IAPManager.self) private var iap

    @State private var showPaywall = false

    private var visibleEntries: [HistoryEntry] {
        iap.isPremium ? store.history : Array(store.history.prefix(WheelStore.freeHistoryCap))
    }

    private var grouped: [(Date, [HistoryEntry])] {
        let cal = Calendar.current
        let dict = Dictionary(grouping: visibleEntries) { entry in
            cal.startOfDay(for: entry.timestamp)
        }
        return dict.keys.sorted(by: >).map { day in (day, dict[day]!) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if visibleEntries.isEmpty {
                    ContentUnavailableView(
                        LocalizedStringKey("No spins yet"),
                        systemImage: "clock.arrow.circlepath",
                        description: Text(LocalizedStringKey("Spin the wheel to start recording history."))
                    )
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                            ForEach(grouped, id: \.0) { day, entries in
                                Section {
                                    ForEach(entries) { entry in
                                        entryRow(entry)
                                            .padding(.horizontal)
                                        Divider().padding(.leading)
                                    }
                                } header: {
                                    sectionHeader(day)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(Text("History"))
            .toolbar {
                if iap.isPremium && !store.history.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(LocalizedStringKey("Clear"), role: .destructive) { store.clearHistory() }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !iap.isPremium {
                    freeUpgradeBanner
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    @ViewBuilder
    private func sectionHeader(_ day: Date) -> some View {
        Text(day, style: .date)
            .font(.subheadline.bold())
            .foregroundStyle(.secondary)
            .padding(.horizontal)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial)
    }

    @ViewBuilder
    private func entryRow(_ entry: HistoryEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.choice)
                .font(.body.bold())
            HStack(spacing: 4) {
                Text(entry.listName)
                Text("·")
                Text(entry.timestamp, style: .time)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 10)
    }

    private var freeUpgradeBanner: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Showing last \(WheelStore.freeHistoryCap) spins")
                    .font(.caption.bold())
                Text("Upgrade for unlimited history")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(LocalizedStringKey("Upgrade")) { showPaywall = true }
                .font(.caption.bold())
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Settings Tab

private struct SettingsTab: View {
    @Environment(WheelStore.self) private var store
    @Environment(IAPManager.self) private var iap
    @Environment(LocalizationManager.self) private var l10n

    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            List {
                Section(LocalizedStringKey("Theme")) {
                    let cols = [GridItem(.adaptive(minimum: 88), spacing: 12)]
                    LazyVGrid(columns: cols, spacing: 12) {
                        ForEach(WheelTheme.all) { theme in
                            ThemeTile(theme: theme, isSelected: theme.id == store.selectedThemeID, isPremium: iap.isPremium)
                                .onTapGesture {
                                    if theme.isPremium && !iap.isPremium {
                                        showPaywall = true
                                    } else {
                                        store.setTheme(theme.id)
                                    }
                                }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section(LocalizedStringKey("Language")) {
                    LanguagePicker()
                }

                Section(LocalizedStringKey("Premium")) {
                    if iap.isPremium {
                        Label(LocalizedStringKey("Premium unlocked"), systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button { showPaywall = true } label: {
                            Label(LocalizedStringKey("Unlock Premium"), systemImage: "sparkles")
                        }
                    }
                    Button(LocalizedStringKey("Restore Purchase")) { Task { await iap.restore() } }
                }

                Section(LocalizedStringKey("About")) {
                    LabeledContent(LocalizedStringKey("Version"), value: appVersion)
                    LabeledContent(LocalizedStringKey("Build"),   value: buildNumber)
                    Link(LocalizedStringKey("Privacy Policy"), destination: URL(string: "https://github.com/jiejuefuyou/autoapp-hello/blob/main/PRIVACY.md")!)
                    Link(LocalizedStringKey("Terms of Use"), destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                    Label(LocalizedStringKey("No data collected. Ever."), systemImage: "lock.shield.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(Text("Settings"))
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }
}

private struct ThemeTile: View {
    let theme: WheelTheme
    let isSelected: Bool
    let isPremium: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(.angularGradient(colors: theme.palette, center: .center, startAngle: .zero, endAngle: .degrees(360)))
                    .frame(width: 64, height: 64)
                    .overlay(
                        Circle().strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 3)
                    )
                if theme.isPremium && !isPremium {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(.black.opacity(0.55), in: Circle())
                }
            }
            Text(theme.displayName)
                .font(.caption2)
                .lineLimit(1)
        }
    }
}

private struct LanguagePicker: View {
    @Environment(LocalizationManager.self) private var l10n

    var body: some View {
        Picker(LocalizedStringKey("Language"), selection: Binding(
            get: { l10n.override },
            set: { l10n.setOverride($0) }
        )) {
            Text(LocalizedStringKey("System default")).tag("")
            ForEach(LocalizationManager.supportedLanguages, id: \.self) { code in
                Text(LocalizationManager.displayName(for: code)).tag(code)
            }
        }
        .pickerStyle(.menu)
    }
}

#Preview {
    ContentView()
        .environment(WheelStore())
        .environment(IAPManager())
        .environment(LocalizationManager.shared)
}
