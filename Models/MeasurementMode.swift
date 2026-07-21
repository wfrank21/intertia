import Foundation

/// Beschreibt einen Messmodus: Startgeschwindigkeit, Zielgeschwindigkeit
/// (bis wohin beschleunigt wird) und optional eine anschließende Bremsphase
/// bis zu einer weiteren Geschwindigkeit (z.B. 0-100-0 oder frei wählbar
/// wie 60-140-80).
struct MeasurementMode: Identifiable, Codable, Equatable, Hashable {
    var id = UUID()
    var name: String
    var startSpeedKmh: Double
    var targetSpeedKmh: Double
    /// Wenn gesetzt, wird nach Erreichen von `targetSpeedKmh` weitergemessen,
    /// bis diese (niedrigere) Geschwindigkeit erreicht ist. `nil` bedeutet:
    /// keine Bremsphase, Messung endet bei `targetSpeedKmh`.
    var brakeToSpeedKmh: Double?

    var includesBraking: Bool { brakeToSpeedKmh != nil }

    static let zeroToHundred = MeasurementMode(
        name: "0–100 km/h",
        startSpeedKmh: 0,
        targetSpeedKmh: 100,
        brakeToSpeedKmh: nil
    )

    static let zeroToHundredToZero = MeasurementMode(
        name: "0–100–0 km/h",
        startSpeedKmh: 0,
        targetSpeedKmh: 100,
        brakeToSpeedKmh: 0
    )

    static let hundredToTwoHundred = MeasurementMode(
        name: "100–200 km/h",
        startSpeedKmh: 100,
        targetSpeedKmh: 200,
        brakeToSpeedKmh: nil
    )

    /// Frei wählbarer Modus mit zwei Geschwindigkeiten (a–b), ohne Bremsphase.
    static func custom(from: Double, to: Double) -> MeasurementMode {
        MeasurementMode(
            name: "\(Int(from))–\(Int(to)) km/h",
            startSpeedKmh: from,
            targetSpeedKmh: to,
            brakeToSpeedKmh: nil
        )
    }

    /// Frei wählbarer Modus mit drei Geschwindigkeiten (a–b–c): Beschleunigen
    /// von a auf b, danach Bremsen auf c (z.B. 0–100–50 oder 60–140–80).
    static func custom(from: Double, to: Double, brakeTo: Double) -> MeasurementMode {
        MeasurementMode(
            name: "\(Int(from))–\(Int(to))–\(Int(brakeTo)) km/h",
            startSpeedKmh: from,
            targetSpeedKmh: to,
            brakeToSpeedKmh: brakeTo
        )
    }

    /// Anzeigename in der gewünschten Einheit (unabhängig vom gespeicherten,
    /// immer in km/h verfassten `name`).
    func displayName(unit: SpeedUnit) -> String {
        speedRangeDisplayName(start: startSpeedKmh, target: targetSpeedKmh, brakeTo: brakeToSpeedKmh, unit: unit)
    }
}
