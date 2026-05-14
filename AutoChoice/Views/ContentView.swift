import SwiftUI
import AudioToolbox

struct ContentView: View {
    @Environment(WheelStore.self) private var store
    @Environment(IAPManager.self) private var iap

    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false

    var body: some View {
        TabView {
            WheelTab()
                .tabItem { Label(LocalizedStringKey("Wheel"), systemImage: "circle.grid.cross.fill") }
            HistoryView()
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

    @AppStorage("spinSoundID") private var spinSoundID: String = SoundService.defaultID

    @State private var showPaywall = false
    @State private var showLists = false
    @State private var resultBump = 0
    @State private var tickScheduler: SpinTickScheduler?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                resultBanner

                Spacer(minLength: 8)

                WheelView(
                    choices: store.activeList?.choices ?? [],
                    rotation: store.currentRotation,
                    palette: WheelTheme.by(id: store.selectedThemeID).palette,
                    isSpinning: store.isSpinning,
                    lastResultLabel: store.lastResult?.label
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
                    .accessibilityLabel(Text(LocalizedStringKey("Lists")))
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
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isStaticText)
            .accessibilityLabel(Text(String(format: String(localized: "Result: %@"), result.label)))
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
                .accessibilityLabel(Text(LocalizedStringKey("Share result")))
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
            .accessibilityLabel(Text(LocalizedStringKey("Share result")))
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
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(Text(LocalizedStringKey(store.isSpinning ? "Spinning…" : "Spin the wheel")))
        .accessibilityHint(Text(LocalizedStringKey((store.activeList?.choices.isEmpty ?? true) ? "Add choices first" : "")))
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
        // Premium users hear their selected spin sound; free users always
        // get the silent default so the audio cue stays a Premium-only perk.
        if iap.isPremium {
            SoundService.play(id: spinSoundID)
        }
        store.isSpinning = true
        store.spin(isPremium: iap.isPremium)
        // WheelStore is @Observable (class), safe to capture directly.
        let capturedStore = store
        // Use a local @State holder so the scheduler survives the 3.5 s animation.
        // onComplete runs on main actor (CADisplayLink + @MainActor class).
        // resultBump State mutation is posted back via DispatchQueue.main so the
        // @State setter runs on the next SwiftUI update cycle.
        let sched = SpinTickScheduler(
            onTick: {
                AudioServicesPlaySystemSound(1057)  // Tink
                UISelectionFeedbackGenerator().selectionChanged()
            },
            onComplete: {
                capturedStore.isSpinning = false
                Haptics.success()
                ReviewService.recordSuccess()
                ReviewService.maybeRequestReview()
            }
        )
        tickScheduler = sched
        sched.start()
        // resultBump drives the result-banner id; update it slightly after
        // onComplete so SwiftUI sees the isSpinning → false change first.
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3.55))
            resultBump += 1
            tickScheduler = nil
        }
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

                Section(LocalizedStringKey("Sound")) {
                    SpinSoundPicker(showPaywall: $showPaywall)
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
            Text(theme.displayNameKey)
                .font(.caption2)
                .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(theme.displayNameKey))
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
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

private struct SpinSoundPicker: View {
    @Environment(IAPManager.self) private var iap
    @AppStorage("spinSoundID") private var spinSoundID: String = SoundService.defaultID
    @Binding var showPaywall: Bool

    var body: some View {
        if iap.isPremium {
            Picker(LocalizedStringKey("Spin sound"), selection: $spinSoundID) {
                ForEach(SpinSound.allCases) { sound in
                    Text(LocalizedStringKey(sound.displayKey)).tag(sound.rawValue)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: spinSoundID) { _, new in
                // Preview the new selection so the user hears what they picked.
                SoundService.play(id: new)
            }
        } else {
            Button {
                showPaywall = true
            } label: {
                HStack {
                    Label(LocalizedStringKey("Spin sound"), systemImage: "speaker.wave.2")
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
            .accessibilityLabel(Text(LocalizedStringKey("Spin sound is a Premium feature")))
        }
    }
}

#Preview {
    ContentView()
        .environment(WheelStore())
        .environment(IAPManager())
        .environment(LocalizationManager.shared)
}
