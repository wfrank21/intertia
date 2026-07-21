import Foundation

/// Vom Nutzer in den Einstellungen gewählte App-Sprache, unabhängig von der
/// iOS-Systemsprache.
enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case auto
    case en
    case de

    var id: String { rawValue }

    /// `nil` = keine Override, der Systemsprache folgen.
    var locale: Locale? {
        switch self {
        case .auto: return nil
        case .en: return Locale(identifier: "en")
        case .de: return Locale(identifier: "de")
        }
    }

    /// Für Stellen außerhalb der SwiftUI-Environment (z.B. MeasurementEngine),
    /// die `String(localized:locale:)` direkt mit einer konkreten Locale
    /// aufrufen müssen.
    var resolvedLocale: Locale {
        locale ?? Locale.autoupdatingCurrent
    }

    /// Anzeige-Label mit Flagge. Sprachnamen werden bewusst NICHT übersetzt
    /// (Autonym-Konvention, wie auch bei Apples eigenem Sprachumschalter).
    var flagLabel: String {
        switch self {
        case .auto: return "🌐 Auto"
        case .en: return "🇬🇧 English"
        case .de: return "🇦🇹 Deutsch"
        }
    }

    /// Aktuell gespeicherte Auswahl, gelesen aus UserDefaults – für Stellen,
    /// die keinen SwiftUI-Property-Wrapper-Zugriff haben (z.B. beim
    /// Initialisieren von Stored Properties in MeasurementEngine).
    static var current: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? "") ?? .auto
    }
}
