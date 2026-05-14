// AutoChoice — WheelShareService.swift
// Encodes/decodes shared wheel deep links for both custom URL scheme
// (autochoice://wheel?data=...) and Universal Links
// (https://jiejuefuyou.github.io/autochoice/wheel?data=...).

import Foundation

enum WheelShareService {
    // MARK: - Constants

    static let urlScheme = "autochoice"
    static let universalLinkBase = "https://jiejuefuyou.github.io/autochoice/wheel"

    // MARK: - DTO

    /// Minimal wire-format for a shared wheel.
    /// Only name + choice labels are shared; weight and IDs are local-only.
    struct SharedWheelDTO: Codable, Sendable {
        let name: String
        let choices: [String]
    }

    // MARK: - Encoding

    /// Returns a Universal Link URL for sharing. Falls back to nil on encode failure.
    static func universalURL(list: ChoiceList) -> URL? {
        let dto = SharedWheelDTO(
            name: list.name,
            choices: list.choices.map(\.label)
        )
        guard let encoded = encodedData(dto) else { return nil }
        return URL(string: "\(universalLinkBase)?data=\(encoded)")
    }

    /// Returns a custom URL scheme link (autochoice://wheel?data=…).
    /// Used as the fallback when Universal Links are not available.
    static func schemeURL(list: ChoiceList) -> URL? {
        let dto = SharedWheelDTO(
            name: list.name,
            choices: list.choices.map(\.label)
        )
        guard let encoded = encodedData(dto) else { return nil }
        return URL(string: "\(urlScheme)://wheel?data=\(encoded)")
    }

    // MARK: - Decoding

    /// Decodes a SharedWheelDTO from either a Universal Link or a custom scheme URL.
    /// Returns nil if the URL does not match the expected format.
    static func decodeURL(_ url: URL) -> SharedWheelDTO? {
        guard isShareURL(url) else { return nil }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let dataItem = components.queryItems?.first(where: { $0.name == "data" }),
              let rawValue = dataItem.value else { return nil }
        let b64 = rawValue.removingPercentEncoding ?? rawValue
        guard let data = Data(base64Encoded: b64) else { return nil }
        return try? JSONDecoder().decode(SharedWheelDTO.self, from: data)
    }

    // MARK: - Helpers

    static func isShareURL(_ url: URL) -> Bool {
        if url.scheme == urlScheme && url.host == "wheel" { return true }
        if let host = url.host,
           host == "jiejuefuyou.github.io",
           url.path.hasPrefix("/autochoice/wheel") { return true }
        return false
    }

    private static func encodedData(_ dto: SharedWheelDTO) -> String? {
        guard let json = try? JSONEncoder().encode(dto) else { return nil }
        let b64 = json.base64EncodedString()
        return b64.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
    }
}
