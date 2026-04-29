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
                Section("Lists") {
                    ForEach(store.lists) { list in
                        listRow(list)
                    }
                    Button {
                        addList()
                    } label: {
                        Label("New list", systemImage: "plus.circle")
                    }
                }

                if let active = store.activeList {
                    Section("Choices in \"\(active.name)\"") {
                        ForEach(active.choices) { choice in
                            ChoiceEditRow(choice: choice, list: active)
                        }
                        .onDelete { indices in
                            indices.compactMap { active.choices[safe: $0] }
                                .forEach { store.removeChoice($0, from: active) }
                        }
                        HStack {
                            TextField("Add choice", text: $newChoice)
                                .submitLabel(.done)
                                .onSubmit(addChoice)
                            Button("Add", action: addChoice)
                                .disabled(newChoice.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        if active.choices.count >= WheelStore.freeChoiceLimit && !iap.isPremium {
                            limitNote
                        }
                    }
                }
            }
            .navigationTitle("Manage")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .alert("Rename list", isPresented: Binding(
                get: { renamingList != nil },
                set: { if !$0 { renamingList = nil } }
            )) {
                TextField("Name", text: $newListName)
                Button("Cancel", role: .cancel) { renamingList = nil }
                Button("Save") {
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
                Button("Rename") {
                    renamingList = list
                    newListName = list.name
                }
                if store.lists.count > 1 {
                    Button("Delete", role: .destructive) {
                        store.deleteList(list)
                    }
                }
            } label: {
                Image(systemName: "ellipsis").foregroundStyle(.secondary)
            }
        }
    }

    private var limitNote: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Free tier limit: \(WheelStore.freeChoiceLimit) choices.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("Unlock unlimited") { showPaywall = true }
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
        let next = "List \(store.lists.count + 1)"
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
        TextField("", text: $editing, onCommit: commit)
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
