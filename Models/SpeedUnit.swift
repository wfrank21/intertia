import Foundation

/// Anzeige-Einheit für Geschwindigkeiten. Intern wird in der App immer mit
/// km/h gerechnet (GPS, Beschleunigungssensor) – `SpeedUnit` wird nur für
/// Ein-/Ausgabe in der UI verwendet.
enum SpeedUnit: String, CaseIterable, Identifiable, Codable {
    case kmh
    case mph

    var id: String { rawValue }

    /// Einheiten-Symbol – bewusst nicht lokalisiert, da international gleich.
    var symbol: String {
        switch self {
        case .kmh: return "km/h"
        case .mph: return "mph"
        }
    }

    private var kmhPerUnit: Double {
        switch self {
        case .kmh: return 1.0
        case .mph: return 1.60934
        }
    }

    /// Rechnet einen in km/h vorliegenden Wert in diese Einheit um.
    func fromKmh(_ kmh: Double) -> Double {
        kmh / kmhPerUnit
    }

    /// Rechnet einen in dieser Einheit eingegebenen Wert zurück nach km/h.
    func toKmh(_ value: Double) -> Double {
        value * kmhPerUnit
    }

    /// Ganzzahlige Textdarstellung eines km/h-Werts in dieser Einheit, ohne
    /// Einheiten-Suffix (z.B. für zusammengesetzte Bereichsangaben "0–62").
    func roundedString(_ kmh: Double) -> String {
        "\(Int(fromKmh(kmh).rounded()))"
    }

    /// Ganzzahlige Textdarstellung inkl. Einheiten-Suffix (z.B. "62 mph").
    func formatted(_ kmh: Double) -> String {
        "\(roundedString(kmh)) \(symbol)"
    }
}

/// Baut aus einer Start-/Ziel-/optionalen Bremsgeschwindigkeit (jeweils in
/// km/h) eine Anzeigebezeichnung in der gewünschten Einheit, z.B.
/// "0–100 km/h" oder bei aktivierter Bremsphase "0–100–0 km/h".
func speedRangeDisplayName(start: Double, target: Double, brakeTo: Double?, unit: SpeedUnit) -> String {
    var parts = [unit.roundedString(start), unit.roundedString(target)]
    if let brakeTo {
        parts.append(unit.roundedString(brakeTo))
    }
    return parts.joined(separator: "–") + " " + unit.symbol
}
