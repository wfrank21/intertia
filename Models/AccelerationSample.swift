import Foundation

/// Aus zwei aufeinanderfolgenden `SpeedSample`s abgeleiteter Beschleunigungs-
/// wert (m/s²), verortet am Mittelpunkt des jeweiligen Zeitintervalls.
///
/// Wird bewusst nicht separat gemessen/gespeichert, sondern aus den ohnehin
/// aufgezeichneten GPS-Geschwindigkeits-Samples berechnet (siehe
/// `MeasurementResult.accelerationSamples`). Das vermeidet eine erneute
/// Nutzung des rohen Beschleunigungssensors für Messwerte, die im
/// Sägezahn-Bug bereits zu unschönen Artefakten geführt hat – hier werden
/// stattdessen echte GPS-Geschwindigkeitsdifferenzen durch die verstrichene
/// Zeit geteilt.
struct AccelerationSample: Identifiable, Equatable, Hashable {
    let id = UUID()
    /// Zeit seit Messbeginn in Sekunden (Mittelpunkt des Intervalls).
    let t: TimeInterval
    /// Durchschnittliche Beschleunigung über dieses Intervall, in m/s².
    /// Positiv = Beschleunigen, negativ = Verzögern/Bremsen.
    let accelMS2: Double
}
