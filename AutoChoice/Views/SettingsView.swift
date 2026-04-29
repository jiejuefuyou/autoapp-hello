import SwiftUI

struct SettingsView: View {
    @Environment(WheelStore.self) private var store
    @Environment(IAPManager.self) private var iap
    @Environment(\.dismiss) private var dismiss

    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            List {
                Section("Theme") {
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

                Section("Premium") {
                    if iap.isPremium {
                        Label("Premium unlocked", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button { showPaywall = true } label: {
                            Label("Unlock Premium", systemImage: "sparkles")
                        }
                    }
                    Button("Restore Purchase") { Task { await iap.restore() } }
                }

                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    LabeledContent("Build",   value: buildNumber)
                    Link("Privacy Policy", destination: URL(string: "https://github.com/jiejuefuyou/autoapp-hello/blob/main/PRIVACY.md")!)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
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
