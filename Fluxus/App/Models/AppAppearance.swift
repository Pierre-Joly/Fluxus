import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case black
    case white

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return "System"
        case .black:
            return "Black"
        case .white:
            return "White"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .black:
            return .dark
        case .white:
            return .light
        }
    }

#if canImport(AppKit)
    var nsAppearanceName: NSAppearance.Name? {
        switch self {
        case .system:
            return nil
        case .black:
            return .darkAqua
        case .white:
            return .aqua
        }
    }
#endif

    static func load(from defaults: UserDefaults = .standard) -> AppAppearance {
        guard
            let rawValue = defaults.string(forKey: FluxusViewModelConstants.appearanceDefaultsKey),
            let appearance = AppAppearance(rawValue: rawValue)
        else {
            return .system
        }
        return appearance
    }

    func persist(to defaults: UserDefaults = .standard) {
        defaults.set(rawValue, forKey: FluxusViewModelConstants.appearanceDefaultsKey)
    }
}
