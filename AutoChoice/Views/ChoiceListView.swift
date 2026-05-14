import SwiftUI

struct ChoiceListView: View {
    @Environment(WheelStore.self) private var store
    @Environment(IAPManager.self) private var iap
    @Environment(\.dismiss) private var dismiss

    @State private var showPaywall = false
    @State private var newChoice = ""
    @State private var renamingList: ChoiceList?
    @State private var newListName = ""

    var body: some View {
        NavigationStack {
            List {
                Section(LocalizedStringKey("Lists")) {
                    ForEach(store.lists) { list in
                        listRow(list)
                    }
                    Button {
                        addList()
                    } label: {
                        Label(LocalizedStringKey("New list"), systemImage: "plus.circle")
                    }
                }

                if let active = store.activeList {
                    Section(header: Text(String(format: NSLocalizedString("Choices in \"%@\"", comment: "Section header showing list name"), active.name))) {
                        if active.choices.isEmpty {
                            Text(LocalizedStringKey("Empty list. Tap + to add choices."))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .accessibilityLabel(Text(LocalizedStringKey("Empty list. Tap + to add choices.")))
                        }
                        ForEach(active.choices) { choice in
                            ChoiceEditRow(choice: choice, list: active)
                        }
                        .onDelete { indices in
                            indices.compactMap { active.choices[safe: $0] }
                                .forEach { store.removeChoice($0, from: active) }
                        }
                        HStack {
                            TextField(LocalizedStringKey("Add choice"), text: $newChoice)
                                .submitLabel(.done)
                                .onSubmit(addChoice)
                            Button(LocalizedStringKey("Add"), action: addChoice)
                                .disabled(newChoice.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        if active.choices.count >= WheelStore.freeChoiceLimit && !iap.isPremium {
                            limitNote
                        }
                    }

                    // v1.0.9: soft upsell banner at 5-choice threshold — persistent,
                    // non-blocking (spin still works), shows before the hard 8-choice wall.
                    if !iap.isPremium && (active.choices.count) >= 5 {
                        softUpsellBanner
                    }
                }
            }
            .navigationTitle(Text(LocalizedStringKey("Manage")))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(LocalizedStringKey("Done")) { dismiss() }
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .alert(LocalizedStringKey("Rename list"), isPresented: Binding(
                get: { renamingList != nil },
                set: { if !$0 { renamingList = nil } }
            )) {
                TextField(LocalizedStringKey("Name"), text: $newListName)
                Button(LocalizedStringKey("Cancel"), role: .cancel) { renamingList = nil }
                Button(LocalizedStringKey("Save")) {
                    if let l = renamingList { store.renameList(l, to: newListName) }
                    renamingList = nil
                }
            }
        }
    }

    private func listRow(_ list: ChoiceList) -> some View {
        HStack {
            Button {
                store.setActive(list)
            } label: {
                HStack {
                    Image(systemName: list.id == store.activeListID ? "largecircle.fill.circle" : "circle")
                    VStack(alignment: .leading) {
                        Text(list.name).foregroundStyle(.primary)
                        Text("\(list.choices.count) choices").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            Spacer()
            Menu {
                Button(LocalizedStringKey("Rename")) {
                    renamingList = list
                    newListName = list.name
                }
                if store.lists.count > 1 {
                    Button(LocalizedStringKey("Delete"), role: .destructive) {
                        store.deleteList(list)
                    }
                }
            } label: {
                Image(systemName: "ellipsis").foregroundStyle(.secondary)
            }
        }
    }

    // v1.0.9 — soft banner at 5 choices (non-modal, spin still works)
    private var softUpsellBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.open.fill")
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey("You're using AutoChoice a lot!"))
                    .font(.subheadline.weight(.semibold))
                Text(LocalizedStringKey("Unlock Premium for unlimited lists + themes."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(LocalizedStringKey("Upgrade")) {
                showPaywall = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(12)
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(LocalizedStringKey("You're using AutoChoice a lot! Unlock Premium for unlimited lists + themes.")))
    }

    private var limitNote: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(format: NSLocalizedString("Free tier limit: %lld choices.", comment: "Note shown when user hits free tier choice limit"), WheelStore.freeChoiceLimit))
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button(LocalizedStringKey("Unlock unlimited")) { showPaywall = true }
                .font(.footnote.weight(.semibold))
        }
    }

    private func addChoice() {
        guard let active = store.activeList else { return }
        let trimmed = newChoice.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if active.choices.count >= WheelStore.freeChoiceLimit && !iap.isPremium {
            showPaywall = true
            return
        }
        store.addChoice(trimmed, to: active)
        newChoice = ""
    }

    private func addList() {
        if store.lists.count >= WheelStore.freeListLimit && !iap.isPremium {
            showPaywall = true
            return
        }
        let next = String(format: String(localized: "List %lld"), store.lists.count + 1)
        _ = store.addList(name: next)
    }
}

private struct ChoiceEditRow: View {
    @Environment(WheelStore.self) private var store
    let choice: Choice
    let list: ChoiceList
    @State private var editing: String

    init(choice: Choice, list: ChoiceList) {
        self.choice = choice
        self.list = list
        self._editing = State(initialValue: choice.label)
    }

    var body: some View {
        TextField(LocalizedStringKey("Choice label"), text: $editing, onCommit: commit)
            .submitLabel(.done)
            .onChange(of: editing) { _, _ in }
            .onDisappear(perform: commit)
    }

    private func commit() {
        let trimmed = editing.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != choice.label else { return }
        store.updateChoice(choice, in: list, label: trimmed)
    }
}
