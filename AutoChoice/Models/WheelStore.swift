import Foundation
import Observation

@Observable
final class WheelStore {
    static let freeChoiceLimit = 6
    static let freeListLimit = 1
    static let historyCap = 100
    static let freeHistoryCap = 10

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
    func spin(isPremium: Bool = false) -> Choice? {
        guard let list = activeList, !list.choices.isEmpty else { return nil }
        let chosen = list.choices.randomElement()!
        guard let idx = list.choices.firstIndex(of: chosen) else { return nil }
        let segment = 360.0 / Double(list.choices.count)
        // The wheel renders index 0 starting at the top. Pointer is fixed at the top.
        // To land segment idx center under the pointer, final rotation must satisfy:
        //   finalRotation ≡ -(idx * segment + segment / 2)  (mod 360)
        // Round-5 reject (2.1a, 2026-05-11): the previous formula
        //   currentRotation.truncatingRemainder(360) - rounds * 360 + target
        // does NOT preserve modular equivalence — Swift's truncatingRemainder for negative
        // numbers leaves a negative residue, so after subsequent spins the cumulative
        // rotation drifts and the segment under the pointer no longer matches `chosen`.
        // Fix: anchor the new rotation to a multiple-of-360 baseline derived from the
        // current rotation (via floor division), then add the deterministic target.
        // Note: `rounds` must be an Int (whole turns) so that
        //   (currentLap - rounds) * 360 + target
        // is exactly an integer multiple of 360 plus target — fractional rounds would
        // leave a sub-360° residue and reintroduce the drift the fix is meant to remove.
        let target = -(Double(idx) * segment + segment / 2)
        let rounds = Int.random(in: 5...8)
        let currentLap = (currentRotation / 360).rounded(.down)
        currentRotation = (currentLap - Double(rounds)) * 360 + target
        lastResult = chosen
        history.insert(HistoryEntry(listName: list.name, choice: chosen.label, timestamp: .now), at: 0)
        let cap = isPremium ? Self.historyCap : Self.freeHistoryCap
        if history.count > cap { history = Array(history.prefix(cap)) }
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

        enum CodingKeys: String, CodingKey {
            case lists, activeListID, history, selectedThemeID
        }

        init(lists: [ChoiceList], activeListID: UUID?, history: [HistoryEntry], selectedThemeID: String) {
            self.lists = lists
            self.activeListID = activeListID
            self.history = history
            self.selectedThemeID = selectedThemeID
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.lists           = try c.decode([ChoiceList].self,    forKey: .lists)
            self.activeListID    = try c.decodeIfPresent(UUID.self,   forKey: .activeListID)
            self.history         = (try? c.decode([HistoryEntry].self, forKey: .history)) ?? []
            self.selectedThemeID = try c.decodeIfPresent(String.self, forKey: .selectedThemeID) ?? "classic"
        }
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
