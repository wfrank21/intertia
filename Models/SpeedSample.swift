import Foundation

/// Ein einzelner Geschwindigkeitsmesspunkt während einer Messung.
/// `source` zeigt an, ob der Wert direkt vom GPS stammt oder zwischen zwei
/// GPS-Fixes über den Beschleunigungssensor hochgerechnet ("fused") wurde.
struct SpeedSample: Identifiable, Codable, Equatable, Hashable {
    var id = UUID()
    /// Zeit seit Messbeginn in Sekunden.
    let t: TimeInterval
    let speedKmh: Double
    /// Zurückgelegte Strecke seit Messbeginn bis zu diesem Sample, in Metern.
    /// Ermöglicht es, beim Antippen eines Punkts im Diagramm anzuzeigen, wie
    /// weit das Fahrzeug zu diesem Zeitpunkt bereits gefahren ist.
    let distanceM: Double
    /// Höhenänderung seit Messbeginn bis zu diesem Sample, in Metern
    /// (positiv = Anstieg, negativ = Abstieg). Stammt von `CLLocation.altitude`
    /// (GPS). Bleibt 0, wenn kein Höhensignal verfügbar ist oder der Eintrag
    /// aus einer Vorversion ohne Höhendaten geladen wurde.
    let altitudeM: Double
    /// GPS-Koordinate zu diesem Sample, sofern zum Aufzeichnungszeitpunkt ein
    /// Fix vorlag. Wird für die Streckenkarte im Ergebnis verwendet (siehe
    /// `MeasurementResult.routeCoordinates`). Bei rein rechnerisch
    /// eingefügten Zwischenpunkten (siehe `MeasurementResult.displaySamples`)
    /// bewusst `nil`, damit die Karte keine künstlich geglättete Route
    /// zeichnet, sondern nur echte GPS-Fixes.
    let latitude: Double?
    let longitude: Double?
    let source: String

    init(t: TimeInterval, speedKmh: Double, distanceM: Double, altitudeM: Double, latitude: Double? = nil, longitude: Double? = nil, source: String) {
        self.t = t
        self.speedKmh = speedKmh
        self.distanceM = distanceM
        self.altitudeM = altitudeM
        self.latitude = latitude
        self.longitude = longitude
        self.source = source
    }

    enum CodingKeys: String, CodingKey {
        case id, t, speedKmh, distanceM, altitudeM, latitude, longitude, source
    }

    /// Eigene Decodier-Logik, damit bereits gespeicherte Verlaufseinträge aus
    /// einer Vorversion (ohne `distanceM`/`altitudeM`/`latitude`/`longitude`)
    /// weiterhin geladen werden können – fehlt ein Feld, wird 0 bzw. `nil`
    /// angenommen statt den gesamten Verlaufseintrag zu verwerfen.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        t = try c.decode(TimeInterval.self, forKey: .t)
        speedKmh = try c.decode(Double.self, forKey: .speedKmh)
        distanceM = try c.decodeIfPresent(Double.self, forKey: .distanceM) ?? 0
        altitudeM = try c.decodeIfPresent(Double.self, forKey: .altitudeM) ?? 0
        latitude = try c.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try c.decodeIfPresent(Double.self, forKey: .longitude)
        source = try c.decode(String.self, forKey: .source)
    }
}
