import Foundation
import SwiftUI

struct Choice: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var label: String
}

struct ChoiceList: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var choices: [Choice]
    var createdAt: Date = .now
}

struct HistoryEntry: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    let listName: String
    let choice: String
    let timestamp: Date
}

struct WheelTheme: Identifiable, Hashable {
    let id: String
    let displayName: String
    let palette: [Color]
    let isPremium: Bool

    static let all: [WheelTheme] = [
        // Free
        WheelTheme(id: "classic",  displayName: "Classic", palette: [.red, .orange, .yellow, .green, .blue, .purple], isPremium: false),
        WheelTheme(id: "pastel",   displayName: "Pastel",  palette: [hex("#FFB3BA"), hex("#FFDFBA"), hex("#FFFFBA"), hex("#BAFFC9"), hex("#BAE1FF"), hex("#D5BAFF")], isPremium: false),
        // Premium
        WheelTheme(id: "neon",     displayName: "Neon",     palette: [hex("#FF006E"), hex("#FB5607"), hex("#FFBE0B"), hex("#8338EC"), hex("#3A86FF"), hex("#06FFA5")], isPremium: true),
        WheelTheme(id: "ocean",    displayName: "Ocean",    palette: [hex("#03045E"), hex("#0077B6"), hex("#00B4D8"), hex("#90E0EF"), hex("#CAF0F8")], isPremium: true),
        WheelTheme(id: "sunset",   displayName: "Sunset",   palette: [hex("#F72585"), hex("#B5179E"), hex("#7209B7"), hex("#560BAD"), hex("#3A0CA3")], isPremium: true),
        WheelTheme(id: "forest",   displayName: "Forest",   palette: [hex("#264653"), hex("#2A9D8F"), hex("#E9C46A"), hex("#F4A261"), hex("#E76F51")], isPremium: true),
        WheelTheme(id: "candy",    displayName: "Candy",    palette: [hex("#FF70A6"), hex("#FF9770"), hex("#FFD670"), hex("#E9FF70"), hex("#70D6FF")], isPremium: true),
        WheelTheme(id: "mono",     displayName: "Mono",     palette: [hex("#1A1A1A"), hex("#4D4D4D"), hex("#808080"), hex("#B3B3B3"), hex("#E6E6E6")], isPremium: true),
        WheelTheme(id: "retro",    displayName: "Retro",    palette: [hex("#FFCDB2"), hex("#FFB4A2"), hex("#E5989B"), hex("#B5838D"), hex("#6D6875")], isPremium: true),
        WheelTheme(id: "berry",    displayName: "Berry",    palette: [hex("#590D22"), hex("#800F2F"), hex("#A4133C"), hex("#C9184A"), hex("#FF4D6D"), hex("#FF758F")], isPremium: true),
        WheelTheme(id: "midnight", displayName: "Midnight", palette: [hex("#10002B"), hex("#240046"), hex("#3C096C"), hex("#5A189A"), hex("#7B2CBF"), hex("#9D4EDD")], isPremium: true),
        WheelTheme(id: "earth",    displayName: "Earth",    palette: [hex("#582F0E"), hex("#7F4F24"), hex("#936639"), hex("#A68A64"), hex("#B6AD90"), hex("#C2C5AA")], isPremium: true),
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
