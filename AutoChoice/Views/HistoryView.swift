import SwiftUI

struct HistoryView: View {
    @Environment(WheelStore.self) private var store
    @Environment(IAPManager.self) private var iap
    @Environment(\.dismiss) private var dismiss

    @State private var showPaywall = false

    // Visible entries: premium = all; free = last 10 (already capped in WheelStore.spin)
    private var visibleEntries: [HistoryEntry] {
        iap.isPremium ? store.history : Array(store.history.prefix(WheelStore.freeHistoryCap))
    }

    // Groups: [(dayStart, [HistoryEntry])] sorted newest-first
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
                        "No spins yet",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Spin the wheel to start recording history.")
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
            .navigationTitle("History")
            .toolbar {
                if !store.history.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        if iap.isPremium {
                            Button("Clear", role: .destructive) { store.clearHistory() }
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
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

    // MARK: - Sub-views

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
            Button("Upgrade") { showPaywall = true }
                .font(.caption.bold())
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
}
