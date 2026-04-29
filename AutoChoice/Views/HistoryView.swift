import SwiftUI

struct HistoryView: View {
    @Environment(WheelStore.self) private var store
    @Environment(IAPManager.self) private var iap
    @Environment(\.dismiss) private var dismiss

    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            Group {
                if !iap.isPremium {
                    paywallPrompt
                } else if store.history.isEmpty {
                    ContentUnavailableView("No history yet", systemImage: "clock.arrow.circlepath", description: Text("Spin the wheel to start a history."))
                } else {
                    List {
                        ForEach(store.history) { entry in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.choice).font(.body.bold())
                                HStack {
                                    Text(entry.listName)
                                    Text("·")
                                    Text(entry.timestamp, style: .relative)
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
            .toolbar {
                if iap.isPremium && !store.history.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Clear", role: .destructive) { store.clearHistory() }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    private var paywallPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath").font(.system(size: 48)).foregroundStyle(.tint)
            Text("History is a Premium feature").font(.title3.bold())
            Text("Unlock Premium to keep a record of every spin.").foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Unlock Premium") { showPaywall = true }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
