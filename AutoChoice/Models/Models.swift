import Foundation
import SwiftUI

struct Choice: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var label: String

    init(id: UUID = UUID(), label: String) {
        self.id = id
        self.label = label
    }

    enum CodingKeys: String, CodingKey {
        case id, label
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id    = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.label = try c.decode(String.self,        forKey: .label)
    }
}

struct ChoiceList: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var choices: [Choice]
    var createdAt: Date = .now

    init(id: UUID = UUID(), name: String, choices: [Choice], createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.choices = choices
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id, name, choices, createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id        = try c.decodeIfPresent(UUID.self,     forKey: .id) ?? UUID()
        self.name      = try c.decode(String.self,            forKey: .name)
        self.choices   = try c.decode([Choice].self,          forKey: .choices)
        self.createdAt = try c.decodeIfPresent(Date.self,     forKey: .createdAt) ?? .now
    }
}

struct HistoryEntry: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    let listName: String
    let choice: String
    let timestamp: Date

    init(id: UUID = UUID(), listName: String, choice: String, timestamp: Date) {
        self.id = id
        self.listName = listName
        self.choice = choice
        self.timestamp = timestamp
    }

    enum CodingKeys: String, CodingKey {
        case id, listName, choice, timestamp
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id        = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.listName  = try c.decode(String.self,        forKey: .listName)
        self.choice    = try c.decode(String.self,        forKey: .choice)
        self.timestamp = try c.decode(Date.self,          forKey: .timestamp)
    }
}

struct WheelTheme: Identifiable, Hashable {
    let id: String
    let displayNameKey: LocalizedStringKey
    let palette: [Color]
    let isPremium: Bool

    static let all: [WheelTheme] = [
        // Free (4 themes)
        WheelTheme(id: "classic",  displayNameKey: "Theme.Classic",  palette: [.red, .orange, .yellow, .green, .blue, .purple], isPremium: false),
        WheelTheme(id: "pastel",   displayNameKey: "Theme.Pastel",   palette: [hex("#FFB3BA"), hex("#FFDFBA"), hex("#FFFFBA"), hex("#BAFFC9"), hex("#BAE1FF"), hex("#D5BAFF")], isPremium: false),
        WheelTheme(id: "ocean",    displayNameKey: "Theme.Ocean",    palette: [hex("#03045E"), hex("#0077B6"), hex("#00B4D8"), hex("#90E0EF"), hex("#CAF0F8")], isPremium: false),
        WheelTheme(id: "sunset",   displayNameKey: "Theme.Sunset",   palette: [hex("#F72585"), hex("#B5179E"), hex("#7209B7"), hex("#560BAD"), hex("#3A0CA3")], isPremium: false),
        // Premium
        WheelTheme(id: "neon",     displayNameKey: "Theme.Neon",     palette: [hex("#FF006E"), hex("#FB5607"), hex("#FFBE0B"), hex("#8338EC"), hex("#3A86FF"), hex("#06FFA5")], isPremium: true),
        WheelTheme(id: "forest",   displayNameKey: "Theme.Forest",   palette: [hex("#264653"), hex("#2A9D8F"), hex("#E9C46A"), hex("#F4A261"), hex("#E76F51")], isPremium: true),
        WheelTheme(id: "candy",    displayNameKey: "Theme.Candy",    palette: [hex("#FF70A6"), hex("#FF9770"), hex("#FFD670"), hex("#E9FF70"), hex("#70D6FF")], isPremium: true),
        WheelTheme(id: "mono",     displayNameKey: "Theme.Mono",     palette: [hex("#1A1A1A"), hex("#4D4D4D"), hex("#808080"), hex("#B3B3B3"), hex("#E6E6E6")], isPremium: true),
        WheelTheme(id: "retro",    displayNameKey: "Theme.Retro",    palette: [hex("#FFCDB2"), hex("#FFB4A2"), hex("#E5989B"), hex("#B5838D"), hex("#6D6875")], isPremium: true),
        WheelTheme(id: "berry",    displayNameKey: "Theme.Berry",    palette: [hex("#590D22"), hex("#800F2F"), hex("#A4133C"), hex("#C9184A"), hex("#FF4D6D"), hex("#FF758F")], isPremium: true),
        WheelTheme(id: "midnight", displayNameKey: "Theme.Midnight", palette: [hex("#10002B"), hex("#240046"), hex("#3C096C"), hex("#5A189A"), hex("#7B2CBF"), hex("#9D4EDD")], isPremium: true),
        WheelTheme(id: "earth",    displayNameKey: "Theme.Earth",    palette: [hex("#582F0E"), hex("#7F4F24"), hex("#936639"), hex("#A68A64"), hex("#B6AD90"), hex("#C2C5AA")], isPremium: true),
    ]

    static var classic: WheelTheme { all.first { $0.id == "classic" }! }
    static func by(id: String) -> WheelTheme { all.first { $0.id == id } ?? .classic }
}

private func hex(_ s: String) -> Color {
    let cleaned = s.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    var int: UInt64 = 0
    Scanner(string: cleaned).scanHexInt64(&int)
    let r = Double((int >> 16) & 0xFF) / 255
    let g = Double((int >> 8) & 0xFF) / 255
    let b = Double(int & 0xFF) / 255
    return Color(.sRGB, red: r, green: g, blue: b, opacity: 1)
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
