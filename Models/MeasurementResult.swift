import CoreLocation
import Foundation

/// Ergebnis einer abgeschlossenen Messung, inkl. aller Samples für den
/// Geschwindigkeitsverlauf (Chart) und optionaler Bremswerte.
struct MeasurementResult: Identifiable, Codable, Equatable, Hashable {
    var id = UUID()
    var date: Date
    var modeName: String
    var startSpeedKmh: Double
    var targetSpeedKmh: Double
    /// Zeit von Start bis Erreichen der Zielgeschwindigkeit.
    var elapsedSeconds: Double
    /// Nur gesetzt bei Modi mit Bremsphase (z.B. 0-100-0 oder frei mit drittem
    /// Wert): Zeit vom Erreichen der Zielgeschwindigkeit bis zur Brems-
    /// Zielgeschwindigkeit.
    var brakingSeconds: Double?
    var brakingDistanceMeters: Double?
    /// Geschwindigkeit, bis zu der abgebremst wurde (z.B. 0 bei 0-100-0,
    /// oder ein beliebiger Wert bei frei wählbaren 3-Werte-Modi).
    var brakeToSpeedKmh: Double?
    var totalDistanceMeters: Double
    var topSpeedKmh: Double
    var samples: [SpeedSample]
    /// Anzeigename des bei der Messung ausgewählten Fahrzeugs (z.B.
    /// "BMW M3"), zum Messzeitpunkt eingefroren (`Vehicle.displayName`).
    /// Bleibt dadurch unverändert, auch wenn das Fahrzeug später umbenannt
    /// oder gelöscht wird. `nil`, wenn kein Fahrzeug ausgewählt war.
    var vehicleDisplayName: String?
    /// Baujahr (`Vehicle.year`) und Leistung in PS (`Vehicle.horsepowerPS`)
    /// des ausgewählten Fahrzeugs, ebenfalls zum Zeitpunkt der Auswahl
    /// eingefroren (analog zu `vehicleDisplayName`) – z.B. für die
    /// Share-Sheet-Zusammenfassung (`ResultShareCardView`). `nil`, wenn kein
    /// Fahrzeug ausgewählt war oder das Fahrzeug diese Angabe nicht hat.
    var vehicleYear: Int?
    var vehicleHorsepowerPS: Int?
    /// Frei eingegebener Fahrmodus zur Messung (z.B. "Sport+", "Launch
    /// Control", "Winterreifen"). `nil`, wenn nichts eingegeben wurde.
    var driveMode: String?
    /// Freie Notiz zur Messung (z.B. Bedingungen, Strecke, Reifen), unabhängig
    /// vom Fahrmodus. Kann – wie `vehicleDisplayName` und `driveMode` – auch
    /// nachträglich über `ResultEditView` gesetzt oder geändert werden,
    /// nicht nur beim Messstart. `nil`, wenn nichts eingegeben wurde.
    var notes: String?

    var totalSeconds: Double {
        elapsedSeconds + (brakingSeconds ?? 0)
    }

    /// Anzeigename in der gewünschten Einheit (unabhängig vom gespeicherten,
    /// immer in km/h verfassten `modeName`).
    func displayName(unit: SpeedUnit) -> String {
        speedRangeDisplayName(start: startSpeedKmh, target: targetSpeedKmh, brakeTo: brakeToSpeedKmh, unit: unit)
    }

    /// Aus den Geschwindigkeits-Samples abgeleitete Beschleunigungswerte
    /// (m/s²) zwischen je zwei aufeinanderfolgenden Messpunkten. Sehr kurze
    /// Zeitabstände (< 50 ms, z.B. durch einen doppelten Fix) werden
    /// übersprungen, um unrealistische Ausreißer zu vermeiden.
    var accelerationSamples: [AccelerationSample] {
        guard samples.count > 1 else { return [] }
        var result: [AccelerationSample] = []
        result.reserveCapacity(samples.count - 1)
        for i in 1..<samples.count {
            let prev = samples[i - 1]
            let cur = samples[i]
            let dt = cur.t - prev.t
            guard dt > 0.05 else { continue }
            let dvMS = (cur.speedKmh - prev.speedKmh) / 3.6
            result.append(AccelerationSample(t: (prev.t + cur.t) / 2, accelMS2: dvMS / dt))
        }
        return result
    }

    /// Höchste gemessene Beschleunigung (m/s²) während der Beschleunigungs-
    /// phase (bis zum Erreichen der Zielgeschwindigkeit).
    var maxAccelerationMS2: Double? {
        accelerationSamples.filter { $0.t <= elapsedSeconds }.map(\.accelMS2).max()
    }

    /// Stärkste gemessene Verzögerung (m/s², negativ) während der Bremsphase,
    /// sofern vorhanden.
    var maxDecelerationMS2: Double? {
        guard brakingSeconds != nil else { return nil }
        return accelerationSamples.filter { $0.t > elapsedSeconds }.map(\.accelMS2).min()
    }

    /// Schwellwert (m), um den sich die Höhe von einem festen Referenzpunkt
    /// entfernen muss, bevor die Änderung als echter Anstieg/Abstieg statt
    /// als GPS-Rauschen zählt (siehe `elevationGainAndLoss`). GPS-Höhe
    /// (`CLLocation.altitude`) ist deutlich ungenauer als die horizontale
    /// Position (oft ±10–30 m), ohne Filter würde schon auf einer flachen
    /// Straße ständig scheinbarer Anstieg/Abstieg angezeigt.
    private static let elevationNoiseThresholdM = 2.0

    /// Höhenmeter im Anstieg und Abstieg (m), aus der GPS-Höhenänderung
    /// (`SpeedSample.altitudeM`) berechnet.
    ///
    /// Bewusst NICHT einfach Schritt-für-Schritt zwischen zwei
    /// aufeinanderfolgenden Samples verglichen: Bei ~1 GPS-Update/Sekunde
    /// und einer typischen Messdauer von wenigen Sekunden macht selbst eine
    /// echte, spürbare Steigung pro Schritt oft nur wenige Zentimeter aus –
    /// ein reiner Schritt-Schwellwert hätte solche graduellen, aber realen
    /// Höhenänderungen komplett verschluckt und nie etwas angezeigt.
    /// Stattdessen wird gegen einen festen Referenzpunkt akkumuliert: Erst
    /// wenn die Abweichung vom letzten bestätigten Referenzwert
    /// `elevationNoiseThresholdM` überschreitet, zählt die gesamte
    /// Differenz als Anstieg/Abstieg und der Referenzwert springt auf den
    /// aktuellen Wert. Kleinere Schwankungen darunter bewegen die Referenz
    /// nicht und werden als Rauschen ignoriert. Das ist das gleiche Prinzip,
    /// das z.B. Fitness-/Tracking-Apps für Höhenmeter aus barometrischen
    /// bzw. GPS-Höhendaten verwenden.
    private var elevationGainAndLoss: (gain: Double, loss: Double) {
        guard samples.count > 1 else { return (0, 0) }
        var gain = 0.0
        var loss = 0.0
        var reference = samples[0].altitudeM
        for sample in samples.dropFirst() {
            let diff = sample.altitudeM - reference
            if diff > Self.elevationNoiseThresholdM {
                gain += diff
                reference = sample.altitudeM
            } else if diff < -Self.elevationNoiseThresholdM {
                loss += -diff
                reference = sample.altitudeM
            }
        }
        return (gain, loss)
    }

    var elevationGainM: Double { elevationGainAndLoss.gain }
    var elevationLossM: Double { elevationGainAndLoss.loss }

    /// Ob eine nennenswerte Höhenänderung gemessen wurde (oberhalb des
    /// Rauschfilters). Bleibt `false` auf flacher Strecke, bei fehlendem
    /// GPS-Höhensignal oder bei aus einer Vorversion ohne Höhendaten
    /// geladenen Verlaufseinträgen.
    var hasElevationData: Bool {
        elevationGainM + elevationLossM > 0
    }

    /// Koordinaten der echten (nicht interpolierten) GPS-Samples, für die
    /// Streckenkarte im Ergebnis (`RouteMapView`). Samples ohne Koordinate
    /// (z.B. der allererste, per G-Sensor ausgelöste Startpunkt ohne
    /// frischen GPS-Fix) werden übersprungen statt eine falsche Position
    /// anzunehmen.
    var routeCoordinates: [CLLocationCoordinate2D] {
        samples.compactMap { sample in
            guard let lat = sample.latitude, let lon = sample.longitude else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }

    /// Ob genug echte GPS-Koordinaten vorliegen, um eine sinnvolle
    /// Streckenlinie zu zeichnen (mind. 2 Punkte). Bleibt `false` bei sehr
    /// kurzen Messungen mit nur einem Fix oder bei aus einer Vorversion ohne
    /// Koordinaten geladenen Verlaufseinträgen.
    var hasRouteData: Bool {
        routeCoordinates.count >= 2
    }

    /// Zeitabstand (s) zwischen zwei eingefügten Zwischenpunkten in
    /// `displaySamples`.
    private static let displaySampleStep: Double = 0.1

    /// Für die Diagrammdarstellung verdichtete Samples: GPS liefert nur
    /// ca. 1 Update/Sekunde, wodurch das Diagramm ohne Weiteres nur sehr
    /// wenige sichtbare Punkte hätte. Zwischen je zwei echten,
    /// aufeinanderfolgenden `samples` werden hier zusätzliche, linear
    /// interpolierte Zwischenpunkte (alle `displaySampleStep` Sekunden)
    /// eingefügt – Geschwindigkeit, Strecke und Höhe wandern dabei einfach
    /// linear vom einen zum nächsten echten Messwert. Das ist bewusst
    /// etwas anderes als der frühere, verworfene Ansatz (Beschleunigungs-
    /// sensor zwischen GPS-Fixes aufintegrieren): Hier wird nur zwischen
    /// zwei bereits bekannten, vertrauenswürdigen GPS-Werten interpoliert,
    /// nicht unbegrenzt über einen verrauschten Sensor hochgerechnet – ein
    /// Sägezahn-Effekt kann dadurch nicht entstehen. Für die eigentliche
    /// Messung (Schwellwert-Erkennung, Zeiten, Höhenmeter usw.) bleiben
    /// weiterhin ausschließlich die echten `samples` maßgeblich.
    var displaySamples: [SpeedSample] {
        guard samples.count > 1 else { return samples }
        var result: [SpeedSample] = []
        result.reserveCapacity(samples.count * 8)
        for i in 0..<(samples.count - 1) {
            let a = samples[i]
            let b = samples[i + 1]
            result.append(a)
            let dt = b.t - a.t
            guard dt > Self.displaySampleStep else { continue }
            var t = a.t + Self.displaySampleStep
            while t < b.t {
                let f = (t - a.t) / dt
                result.append(SpeedSample(
                    t: t,
                    speedKmh: a.speedKmh + (b.speedKmh - a.speedKmh) * f,
                    distanceM: a.distanceM + (b.distanceM - a.distanceM) * f,
                    altitudeM: a.altitudeM + (b.altitudeM - a.altitudeM) * f,
                    source: "interpolated"
                ))
                t += Self.displaySampleStep
            }
        }
        result.append(samples[samples.count - 1])
        return result
    }
}
