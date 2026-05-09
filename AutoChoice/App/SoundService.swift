import Foundation
import AudioToolbox

/// Plays a short feedback sound when the wheel is spun.
///
/// Uses `AudioServicesPlaySystemSound` so the app does not need to bundle
/// audio asset files. Each option maps to an iOS-stock SystemSoundID that is
/// short (< 500ms), respects the silent switch, and never blocks the main
/// thread. The `silent` option is a no-op for users who do not want audio
/// feedback at all.
enum SpinSound: String, CaseIterable, Identifiable {
    case classicTick = "classic-tick"
    case chime       = "chime"
    case whoosh      = "whoosh"
    case silent      = "silent"

    var id: String { rawValue }

    /// Localizable display name. The keys are listed in `Localizable.strings`
    /// for every supported language so the picker reads naturally in-locale.
    var displayKey: String {
        switch self {
        case .classicTick: return "Classic tick"
        case .chime:       return "Chime"
        case .whoosh:      return "Whoosh"
        case .silent:      return "Silent"
        }
    }

    /// SystemSoundID for the underlying iOS sound. `nil` for `.silent`.
    fileprivate var systemSoundID: SystemSoundID? {
        switch self {
        case .classicTick: return 1057 // Tink — short percussive tick
        case .chime:       return 1013 // Calypso — bright chime
        case .whoosh:      return 1153 // SwooshUp — airy whoosh
        case .silent:      return nil
        }
    }
}

enum SoundService {
    /// Default sound ID used when `@AppStorage("spinSoundID")` has no value yet.
    static let defaultID: String = SpinSound.classicTick.rawValue

    /// Plays the sound represented by the persisted ID. Unknown IDs fall back
    /// to the default; `.silent` is a no-op. Safe to call from the main thread.
    static func play(id: String) {
        let sound = SpinSound(rawValue: id) ?? SpinSound(rawValue: defaultID) ?? .classicTick
        guard let soundID = sound.systemSoundID else { return }
        AudioServicesPlaySystemSound(soundID)
    }
}
