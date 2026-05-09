import SwiftUI

struct HistoryView: View {
    @Environment(WheelStore.self) private var store
    @Environment(IAPManager.self) private var iap

    @State private var showPaywall = false
    @State private var searchText = ""
    @State private var exportURL: URL?

    // Visible entries before search: premium = all; free = last 10.
    private var baseEntries: [HistoryEntry] {
        iap.isPremium ? store.history : Array(store.history.prefix(WheelStore.freeHistoryCap))
    }

    // After applying the search filter (case-insensitive contains on the
    // result label). Empty query passes everything through.
    private var visibleEntries: [HistoryEntry] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return baseEntries }
        return baseEntries.filter { entry in
            entry.choice.range(of: trimmed, options: .caseInsensitive) != nil
        }
    }

    private var grouped: [(Date, [HistoryEntry])] {
        let cal = Calendar.current
        let dict = Dictionary(grouping: visibleEntries) { entry in
            cal.startOfDay(for: entry.timestamp)
        }
        return dict.keys.sorted(by: >).map { day in (day, dict[day]!) }
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(Text("History"))
                .toolbar {
                    if iap.isPremium && !store.history.isEmpty {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                exportURL = CSVExporter.makeTempURL(from: store.history)
                            } label: {
                                Label(LocalizedStringKey("Export"), systemImage: "square.and.arrow.up")
                            }
                            .accessibilityLabel(Text(LocalizedStringKey("Export history (CSV)")))
                        }
                    }
                    if iap.isPremium && !store.history.isEmpty {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(LocalizedStringKey("Clear"), role: .destructive) { store.clearHistory() }
                        }
                    }
                }
                .searchable(
                    text: $searchText,
                    placement: .navigationBarDrawer(displayMode: .automatic),
                    prompt: Text(LocalizedStringKey("Search history"))
                )
                .safeAreaInset(edge: .bottom) {
                    if !iap.isPremium {
                        freeUpgradeBanner
                    }
                }
                .sheet(isPresented: $showPaywall) { PaywallView() }
                .sheet(item: Binding(
                    get: { exportURL.map { ExportFile(url: $0) } },
                    set: { exportURL = $0?.url }
                )) { file in
                    ExportShareSheet(url: file.url)
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if visibleEntries.isEmpty {
            if isSearching {
                ContentUnavailableView(
                    LocalizedStringKey("No matching spins"),
                    systemImage: "magnifyingglass",
                    description: Text(LocalizedStringKey("Try a different search term."))
                )
            } else {
                ContentUnavailableView(
                    LocalizedStringKey("No spins yet"),
                    systemImage: "clock.arrow.circlepath",
                    description: Text(LocalizedStringKey("Spin the wheel to start recording history."))
                )
            }
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
                Text(String(format: NSLocalizedString("Showing last %lld spins", comment: "Banner shown to free-tier users in History view"), WheelStore.freeHistoryCap))
                    .font(.caption.bold())
                Text(LocalizedStringKey("Upgrade for unlimited history"))
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

// MARK: - CSV Export

/// Wraps a temp file URL so `.sheet(item:)` can drive the share sheet.
private struct ExportFile: Identifiable {
    let url: URL
    var id: URL { url }
}

private enum CSVExporter {
    /// Writes `timestamp,result,list_name` for every entry to a temp file and
    /// returns its URL, or `nil` if the write fails. UTF-8 with BOM so Excel
    /// on Windows opens non-ASCII (Japanese / Chinese) labels correctly.
    static func makeTempURL(from entries: [HistoryEntry]) -> URL? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        var lines: [String] = ["timestamp,result,list_name"]
        for entry in entries {
            let ts = formatter.string(from: entry.timestamp)
            lines.append("\(escape(ts)),\(escape(entry.choice)),\(escape(entry.listName))")
        }
        let body = lines.joined(separator: "\n")
        // UTF-8 BOM helps Excel auto-detect encoding on Windows.
        var data = Data([0xEF, 0xBB, 0xBF])
        data.append(Data(body.utf8))

        let stamp = Int(Date().timeIntervalSince1970)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("autochoice-history-\(stamp).csv")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    /// RFC 4180-style CSV field escape: wrap in quotes if the field contains
    /// a comma, quote, or newline; embedded quotes are doubled.
    private static func escape(_ field: String) -> String {
        let needsQuote = field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r")
        guard needsQuote else { return field }
        let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}

/// UIActivityViewController-backed share sheet. We use this instead of
/// `ShareLink` so the sheet title can be localized via the system share
/// presentation, and so it dismisses cleanly when the user shares the file.
private struct ExportShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        controller.setValue(String(localized: "Export history (CSV)"), forKey: "subject")
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
