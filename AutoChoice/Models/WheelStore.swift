import Foundation
import Observation
import WidgetKit

@Observable
final class WheelStore {
    static let freeChoiceLimit = 8
    static let freeListLimit = 2
    static let historyCap = 100
    static let freeHistoryCap = 25
    private static let undoLimit = 10
    private static let appGroupID = "group.com.jiejuefuyou.autochoice"

    var lists: [ChoiceList] = []
    var activeListID: UUID?
    var history: [HistoryEntry] = []
    var selectedThemeID: String = "classic"

    var currentRotation: Double = 0
    var isSpinning: Bool = false
    var lastResult: Choice?

    // MARK: - Undo

    /// Lightweight record pushed before each spin so the user can revert.
    struct SpinRecord {
        let listID: UUID
        let resultLabel: String
        let rotationBefore: Double
        let historyEntryTimestamp: Date
    }

    private(set) var undoStack: [SpinRecord] = []

    var canUndo: Bool { !undoStack.isEmpty }

    /// Reverts to the state immediately before the last spin.
    /// Returns true on success, false if stack is empty.
    @discardableResult
    func undoLastSpin() -> Bool {
        guard let last = undoStack.popLast() else { return false }
        currentRotation = last.rotationBefore
        lastResult = nil
        // Remove the matching history entry (best-effort: same listID + timestamp).
        history.removeAll {
            $0.timestamp == last.historyEntryTimestamp
        }
        save()
        return true
    }

    init() {
        load()
        if lists.isEmpty {
            seed()
        }
    }

    private func seed() {
        let starter = ChoiceList(
            name: String(localized: "What to eat?"),
            choices: [
                Choice(label: String(localized: "Pizza")),
                Choice(label: String(localized: "Sushi")),
                Choice(label: String(localized: "Burger")),
                Choice(label: String(localized: "Salad")),
                Choice(label: String(localized: "Pasta")),
                Choice(label: String(localized: "Tacos")),
            ]
        )
        let userList = ChoiceList(name: String(localized: "My list"), choices: [])
        lists = [starter, userList]
        activeListID = starter.id
        save()
    }

    /// Legacy English seed signature — lists loaded from disk that exactly match
    /// this were seeded before i18n support (v1.0.6 and earlier). Discard them
    /// and re-seed so returning users get native-language defaults.
    private var isLegacyEnglishSeed: Bool {
        guard lists.count == 1 else { return false }
        let list = lists[0]
        guard list.name == "What to eat?" else { return false }
        let expected = ["Pizza", "Sushi", "Burger", "Salad", "Pasta", "Tacos"]
        return list.choices.map(\.label) == expected
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

    /// Updates the spin weight for a single choice. Clamped to [0.1, 10.0].
    /// Premium-only guard is enforced at the call site (ChoiceEditRow).
    func updateChoiceWeight(_ choice: Choice, in list: ChoiceList, weight: Double) {
        guard let li = lists.firstIndex(where: { $0.id == list.id }),
              let ci = lists[li].choices.firstIndex(where: { $0.id == choice.id }) else { return }
        lists[li].choices[ci].weight = min(max(0.1, weight), 10.0)
        save()
    }

    @discardableResult
    func spin(isPremium: Bool = false) -> Choice? {
        guard let list = activeList, !list.choices.isEmpty else { return nil }

        // Weighted random selection. Falls back to uniform if all weights are default (1.0).
        let chosen = isPremium ? weightedRandomChoice(from: list.choices) : list.choices.randomElement()!
        guard let idx = list.choices.firstIndex(of: chosen) else { return nil }

        // Segment angle. For weighted spin, each segment is proportional to its weight.
        // The visual wheel still uses equal segments, so pointer accuracy is only
        // meaningful when weight equals the visual angle share. The full visual-weighted
        // wheel (WheelView) renders by actual weight. We target the correct visual center.
        let angles = segmentAngles(choices: list.choices)
        let segCenter = angles[idx].start + (angles[idx].end - angles[idx].start) / 2

        // The wheel renders index 0 starting at the top. Pointer is fixed at the top.
        // target is the visual center of the chosen segment, negated because rotation
        // is clockwise in SwiftUI but angles increase counter-clockwise in math.
        // Floor-divide anchor ensures no truncatingRemainder drift (lesson 15d).
        let target = -segCenter
        let rounds = Int.random(in: 5...8)
        let currentLap = (currentRotation / 360).rounded(.down)
        let rotationBefore = currentRotation
        currentRotation = (currentLap - Double(rounds)) * 360 + target

        let entryTimestamp = Date.now
        lastResult = chosen
        history.insert(HistoryEntry(listName: list.name, choice: chosen.label, timestamp: entryTimestamp), at: 0)
        let cap = isPremium ? Self.historyCap : Self.freeHistoryCap
        if history.count > cap { history = Array(history.prefix(cap)) }

        // Push undo record.
        let record = SpinRecord(
            listID: list.id,
            resultLabel: chosen.label,
            rotationBefore: rotationBefore,
            historyEntryTimestamp: entryTimestamp
        )
        undoStack.append(record)
        if undoStack.count > Self.undoLimit {
            undoStack.removeFirst(undoStack.count - Self.undoLimit)
        }

        save()
        updateWidgetSharedData()
        return chosen
    }

    // MARK: - Weighted spin helpers

    /// Selects a choice proportional to each choice's weight.
    private func weightedRandomChoice(from choices: [Choice]) -> Choice {
        let clampedWeights = choices.map { max(0.1, $0.weight) }
        let totalWeight = clampedWeights.reduce(0.0, +)
        let pick = Double.random(in: 0..<totalWeight)
        var cumulative = 0.0
        for (choice, w) in zip(choices, clampedWeights) {
            cumulative += w
            if pick < cumulative { return choice }
        }
        return choices[choices.count - 1]
    }

    /// Returns the visual start/end angles (degrees) for each choice, weighted by Choice.weight.
    /// Used both by spin() for pointer targeting and by WheelView for rendering.
    func segmentAngles(choices: [Choice]) -> [(start: Double, end: Double)] {
        let clampedWeights = choices.map { max(0.1, $0.weight) }
        let totalWeight = clampedWeights.reduce(0.0, +)
        var result: [(start: Double, end: Double)] = []
        var current = 0.0
        for w in clampedWeights {
            let angle = (w / totalWeight) * 360.0
            result.append((start: current, end: current + angle))
            current += angle
        }
        return result
    }

    // MARK: - Widget data

    /// Writes the most recent spin result to the shared App Group defaults
    /// so the WidgetKit extension can display it without launching the app.
    private func updateWidgetSharedData() {
        let defaults = UserDefaults(suiteName: Self.appGroupID)
        defaults?.set(activeList?.name ?? "AutoChoice", forKey: "lastListName")
        defaults?.set(lastResult?.label, forKey: "lastResult")
        defaults?.set(activeList?.choices.count ?? 0, forKey: "lastChoiceCount")
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Shared wheel import (deep link / Universal Link)

    /// Imports a shared wheel from a WheelShareService.SharedWheelDTO.
    /// Free users are capped at freeChoiceLimit with an in-app toast.
    /// Returns a brief user-facing message describing what happened.
    @discardableResult
    func importSharedWheel(_ dto: WheelShareService.SharedWheelDTO, isPremium: Bool = false) -> String {
        var choiceLabels = dto.choices
        var cappedNote = ""
        if !isPremium && choiceLabels.count > Self.freeChoiceLimit {
            choiceLabels = Array(choiceLabels.prefix(Self.freeChoiceLimit))
            cappedNote = String(localized: "This wheel has too many choices for free tier. Showing first 8.")
        }
        let newList = ChoiceList(
            name: dto.name,
            choices: choiceLabels.map { Choice(label: $0) }
        )
        // Cap total lists for free users.
        if !isPremium && lists.count >= Self.freeListLimit {
            // Replace active list rather than adding.
            if let idx = lists.firstIndex(where: { $0.id == activeListID }) {
                lists[idx] = newList
            } else {
                lists[0] = newList
            }
        } else {
            lists.append(newList)
        }
        activeListID = newList.id
        save()
        let toast = String(
            format: String(localized: "Imported %@ — \"%@\""),
            dto.name, dto.name
        )
        return cappedNote.isEmpty ? toast : cappedNote
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
        // Data migration: if the persisted data is the legacy English seed (shipped
        // before v1.0.7 i18n support), discard it so seed() is called with the
        // current locale — returning users get native-language defaults.
        if isLegacyEnglishSeed {
            lists = []
            activeListID = nil
        }
    }
}
