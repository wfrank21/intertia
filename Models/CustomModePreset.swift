import Foundation

/// Ein vom Nutzer gespeicherter, frei konfigurierter Messmodus (z.B.
/// „50–100 km/h"), damit häufig genutzte Geschwindigkeitsbereiche nicht
/// jedes Mal neu über die Freitext-Felder im „Frei"-Modus eingegeben werden
/// müssen. Wird auf dem Messbildschirm als Schnellauswahl-Chip angezeigt.
struct CustomModePreset: Identifiable, Codable, Equatable, Hashable {
    var id = UUID()
    /// Vom Nutzer vergebener Name, z.B. „Zwischenspurt". Optional – ist er
    /// leer, wird stattdessen der Geschwindigkeitsbereich als Name verwendet
    /// (siehe `displayName(unit:)`).
    var name: String = ""
    var fromKmh: Double
    var toKmh: Double
    var includesBraking: Bool
    var brakeToKmh: Double

    /// Wandelt das Preset in einen ausführbaren `MeasurementMode` um.
    var mode: MeasurementMode {
        includesBraking ? .custom(from: fromKmh, to: toKmh, brakeTo: brakeToKmh) : .custom(from: fromKmh, to: toKmh)
    }

    func displayName(unit: SpeedUnit) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? mode.displayName(unit: unit) : trimmed
    }
}
