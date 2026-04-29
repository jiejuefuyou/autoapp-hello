import Foundation
import Observation

@Observable
final class WheelStore {
    static let freeChoiceLimit = 6
    static let freeListLimit = 1
    static let historyCap = 100

    var lists: [ChoiceList] = []
    var activeListID: UUID?
    var history: [HistoryEntry] = []
    var selectedThemeID: String = "classic"

    var currentRotation: Double = 0
    var isSpinning: Bool = false
    var lastResult: Choice?

    init() {
        load()
        if lists.isEmpty {
            seed()
        }
    }

    private func seed() {
        let starter = ChoiceList(
            name: "What to eat?",
            choices: [
                Choice(label: "Pizza"),
                Choice(label: "Sushi"),
                Choice(label: "Burger"),
                Choice(label: "Salad"),
                Choice(label: "Pasta"),
                Choice(label: "Tacos"),
            ]
        )
        lists = [starter]
        activeListID = starter.id
        save()
    }

    var activeList: ChoiceList? {
        guard let id = activeListID else { return lists.first }
        return lists.first { $0.id == id } ?? lists.first
    }

    func setActive(_ list: ChoiceList) {
        activeListID = list.id
        save()
    }

    func addList(name: String) -> ChoiceList {
        let new = ChoiceList(name: name, choices: [])
        lists.append(new)
        activeListID = new.id
        save()
        return new
    }

    func deleteList(_ list: ChoiceList) {
        lists.removeAll { $0.id == list.id }
        if activeListID == list.id { activeListID = lists.first?.id }
        save()
    }

    func renameList(_ list: ChoiceList, to name: String) {
        guard let idx = lists.firstIndex(where: { $0.id == list.id }) else { return }
        lists[idx].name = name
        save()
    }

    func addChoice(_ label: String, to list: ChoiceList) {
        guard let idx = lists.firstIndex(where: { $0.id == list.id }) else { return }
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        lists[idx].choices.append(Choice(label: trimmed))
        save()
    }

    func removeChoice(_ choice: Choice, from list: ChoiceList) {
        guard let idx = lists.firstIndex(where: { $0.id == list.id }) else { return }
        lists[idx].choices.removeAll { $0.id == choice.id }
        save()
    }

    func updateChoice(_ choice: Choice, in list: ChoiceList, label: String) {
        guard let li = lists.firstIndex(where: { $0.id == list.id }),
              let ci = lists[li].choices.firstIndex(where: { $0.id == choice.id }) else { return }
        lists[li].choices[ci].label = label
        save()
    }

    @discardableResult
    func spin() -> Choice? {
        guard let list = activeList, !list.choices.isEmpty else { return nil }
        let chosen = list.choices.randomElement()!
        guard let idx = list.choices.firstIndex(of: chosen) else { return nil }
        let segment = 360.0 / Double(list.choices.count)
        // The wheel renders index 0 starting at the top. Pointer is fixed at the top.
        // To land segment idx under the pointer, rotate so the segment center aligns at -90° (top).
        let target = -(Double(idx) * segment + segment / 2)
        let rounds = Double.random(in: 5...8)
        currentRotation = currentRotation.truncatingRemainder(dividingBy: 360) - rounds * 360 + target
        lastResult = chosen
        history.insert(HistoryEntry(listName: list.name, choice: chosen.label, timestamp: .now), at: 0)
        if history.count > Self.historyCap { history = Array(history.prefix(Self.historyCap)) }
        save()
        return chosen
    }

    func clearHistory() {
        history.removeAll()
        save()
    }

    func setTheme(_ id: String) {
        selectedThemeID = id
        save()
    }

    // MARK: - Persistence

    private struct Snapshot: Codable {
        var lists: [ChoiceList]
        var activeListID: UUID?
        var history: [HistoryEntry]
        var selectedThemeID: String
    }

    private var saveURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("autochoice_state.json")
    }

    private func save() {
        let snap = Snapshot(lists: lists, activeListID: activeListID, history: history, selectedThemeID: selectedThemeID)
        do {
            let data = try JSONEncoder().encode(snap)
            try data.write(to: saveURL, options: .atomic)
        } catch {
            // Persistence is non-critical; state is rebuilt from defaults next launch.
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: saveURL),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        lists = snap.lists
        activeListID = snap.activeListID
        history = snap.history
        selectedThemeID = snap.selectedThemeID
    }
}
