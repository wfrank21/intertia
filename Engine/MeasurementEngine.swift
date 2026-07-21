import Combine
import CoreLocation
import CoreMotion
import Foundation

enum EngineState: Equatable {
    /// Kein Messvorgang aktiv.
    case idle
    /// Modus mit Start bei 0 km/h: wartet auf den G-Sensor-Trigger (Losfahren).
    case armedStationary
    /// Modus mit Start > 0 km/h (z.B. 100-200): wartet, bis GPS die
    /// Startgeschwindigkeit meldet.
    case armedRolling
    /// Messung läuft, bis Zielgeschwindigkeit erreicht ist.
    case measuringToTarget
    /// Nur bei Modi mit Bremsphase: misst weiter bis Stillstand.
    case measuringBraking
    /// Messung abgeschlossen, Ergebnis liegt vor.
    case finished
}

/// Steuert den kompletten Messablauf:
///
/// 1. **Start-Erkennung**: Bei Modi, die bei 0 km/h beginnen, erkennt der
///    G-Sensor (CoreMotion `userAcceleration`) den Moment des Anfahrens
///    deutlich präziser als GPS (bis zu 100 Hz statt ~1 Hz). Sobald der
///    Trigger ausgelöst hat, wird der Bewegungssensor wieder gestoppt – er
///    dient ausschließlich der Start-Erkennung, nicht der laufenden
///    Geschwindigkeitsmessung (siehe Punkt 2).
/// 2. **Geschwindigkeitsmessung**: Die Geschwindigkeit kommt ausschließlich
///    von GPS (`CLLocation.speed`). Eine frühere Version hat zwischen
///    GPS-Fixes zusätzlich den Beschleunigungssensor aufintegriert, um eine
///    feinere Auflösung zu bekommen – das führte aber zu sichtbaren Zacken
///    im Geschwindigkeitsverlauf: Der Betrag der horizontalen Beschleunigung
///    (Erschütterungen, Lenkbewegungen, kurzes Gas-Wegnehmen, Rauschen) ist
///    immer positiv und wurde immer als Vortrieb gewertet, wodurch die
///    hochgerechnete Geschwindigkeit zwischen zwei GPS-Fixes systematisch
///    nach oben driftete und beim nächsten GPS-Fix wieder nach unten
///    korrigiert wurde ("Sägezahn"). Für die genaue Zeitmessung wird
///    stattdessen zwischen zwei GPS-Samples linear interpoliert (siehe
///    `interpolatedCrossing`), was ohne dieses Rauschen eine präzise
///    Zielzeit liefert.
/// 3. **Strecke**: Wird aus der tatsächlichen GPS-Distanz zwischen
///    aufeinanderfolgenden Fixes summiert (`CLLocation.distance(from:)`),
///    nicht aus integrierter Geschwindigkeit.
/// 4. **Höhe**: Kommt von `CLLocation.altitude` (GPS), normalisiert auf den
///    exakten Messbeginn (0 m dort). Ein barometrischer Ansatz (`CMAltimeter`)
///    wurde bewusst wieder verworfen: In einer geschlossenen Fahrgastzelle
///    erzeugen Türen, Fenster und die Lüftung Druckstöße, die der Barometer
///    fälschlich als Höhenänderung interpretiert – die Werte wirkten dadurch
///    unzuverlässig. GPS-Höhe ist zwar selbst ungenauer (oft ±10–30 m
///    vertikale Genauigkeit), aber nicht durch Fahrzeuginnenraum-Effekte
///    verfälscht. `MeasurementResult` filtert zusätzlich kleine Ausreißer
///    zwischen zwei Samples heraus (siehe `elevationGainM`/`elevationLossM`).
final class MeasurementEngine: ObservableObject {
    @Published private(set) var state: EngineState = .idle
    @Published private(set) var mode: MeasurementMode = .zeroToHundred
    @Published private(set) var currentSpeedKmh: Double = 0
    @Published private(set) var elapsed: Double = 0
    @Published private(set) var brakingElapsed: Double = 0
    @Published private(set) var lastResult: MeasurementResult?
    @Published private(set) var statusText: String = String(localized: "Bereit", locale: AppLanguage.current.resolvedLocale)
    @Published private(set) var gpsAccuracy: Double = -1
    @Published private(set) var gpsVerticalAccuracy: Double = -1

    private let motion = MotionManager()
    private let location = LocationManager()

    private var samples: [SpeedSample] = []
    private var startTimestamp: TimeInterval?
    private var targetReachedTimestamp: TimeInterval?
    private var accelTriggerThreshold: Double = 0.22
    private var accelSustainCount = 0
    private var totalDistance: Double = 0
    private var brakingStartDistance: Double = 0
    private var topSpeed: Double = 0

    /// Letzte von GPS gemeldete Höhe (m über Meeresspiegel), unabhängig vom
    /// Messstatus laufend aktualisiert – damit beim stationären Start (per
    /// G-Sensor ausgelöst, ohne dass in dem Moment ein frischer GPS-Fix
    /// vorliegt) trotzdem ein aktueller Referenzwert verfügbar ist.
    private var lastKnownAltitude: Double = 0
    /// Höhe zum exakten Messbeginn (Trigger bzw. Startgeschwindigkeit
    /// erreicht), um `SpeedSample.altitudeM` auf "Höhenänderung seit
    /// Start" zu normalisieren statt auf absolute Meereshöhe.
    private var altitudeAtStart: Double?

    /// Letzte von GPS gemeldete Koordinate, analog zu `lastKnownAltitude` –
    /// damit auch der stationäre Startpunkt (per G-Sensor ausgelöst, ohne
    /// dass in dem Moment zwingend ein frischer GPS-Fix vorliegt) für die
    /// Streckenkarte einen brauchbaren Referenzpunkt bekommt.
    private var lastKnownCoordinate: CLLocationCoordinate2D?

    /// Anzeigename des für diese Messung ausgewählten Fahrzeugs, vom
    /// Nutzer in `MeasurementView` gewählt und beim Start eingefroren.
    private var selectedVehicleDisplayName: String?
    /// Baujahr und PS des ausgewählten Fahrzeugs, ebenfalls beim Start
    /// eingefroren (siehe `MeasurementResult.vehicleYear`/
    /// `.vehicleHorsepowerPS`).
    private var selectedVehicleYear: Int?
    private var selectedVehicleHorsepowerPS: Int?
    /// Frei eingegebener Fahrmodus für diese Messung.
    private var selectedDriveMode: String?
    /// Frei eingegebene Notiz für diese Messung (z.B. Bedingungen), bereits
    /// vor Messstart in `MeasurementView` eintragbar – zusätzlich auch
    /// nachträglich über `ResultEditView` änderbar.
    private var selectedNotes: String?

    /// Letzter empfangener GPS-Fix, um zwischen zwei aufeinanderfolgenden
    /// Samples linear interpolieren (Zielzeitpunkt) bzw. die zurückgelegte
    /// Strecke berechnen zu können.
    private var previousLocation: CLLocation?

    /// Mindestanzahl an aufeinanderfolgenden 100-Hz-Samples über der
    /// Schwelle, bevor der Start ausgelöst wird (Rauschunterdrückung, ~30 ms).
    private let requiredSustainSamples = 3

    /// Nach dieser Zeit (Sekunden seit Messstart) wird eine laufende
    /// Messung automatisch abgebrochen, falls das Ziel noch nicht erreicht
    /// wurde (Sicherheitsnetz gegen GPS-Ausfall oder Fehlauslösung). Bewusst
    /// großzügig bemessen: Im „Frei"-Modus kann ein moderater
    /// Geschwindigkeitsbereich (z.B. 50–90 km/h) bei gemächlicher, nicht
    /// vollgasgefahrener Fahrweise durchaus mehrere Minuten dauern – ein zu
    /// knappes Zeitlimit hätte sonst legitime, lange Messungen abgewürgt.
    private static let safetyTimeoutSeconds: TimeInterval = 300

    var locationAuthorizationStatus: CLAuthorizationStatus {
        location.authorizationStatus
    }

    /// Vom Nutzer in den Einstellungen gewählte Anzeigeeinheit, gelesen aus
    /// UserDefaults (gleiches Muster wie `accelSensitivity`).
    private var currentUnit: SpeedUnit {
        SpeedUnit(rawValue: UserDefaults.standard.string(forKey: "speedUnit") ?? "") ?? .kmh
    }

    /// Vom Nutzer in den Einstellungen gewählte App-Sprache (unabhängig von
    /// der Systemsprache), für die manuell übersetzten Statustexte.
    private var currentLocale: Locale {
        AppLanguage.current.resolvedLocale
    }

    init() {
        location.onLocation = { [weak self] loc in self?.handleLocation(loc) }
        motion.onUpdate = { [weak self] m in self?.handleMotion(m) }
    }

    func requestPermissions() {
        location.requestAuthorization()
    }

    /// Bewaffnet die Messung für den übergebenen Modus und startet die
    /// Sensoren. Bei stationärem Start wird zusätzlich der G-Sensor
    /// gestartet, um den Anfahr-Moment präzise zu erkennen; bei rollendem
    /// Start reicht GPS, da hier ohnehin auf das Erreichen der
    /// Startgeschwindigkeit gewartet wird.
    func arm(
        mode: MeasurementMode,
        vehicleDisplayName: String? = nil,
        vehicleYear: Int? = nil,
        vehicleHorsepowerPS: Int? = nil,
        driveMode: String? = nil,
        notes: String? = nil
    ) {
        self.mode = mode
        self.selectedVehicleDisplayName = vehicleDisplayName
        self.selectedVehicleYear = vehicleYear
        self.selectedVehicleHorsepowerPS = vehicleHorsepowerPS
        self.selectedDriveMode = driveMode
        self.selectedNotes = notes
        reset()

        let stored = UserDefaults.standard.double(forKey: "accelSensitivity")
        accelTriggerThreshold = stored > 0 ? stored : 0.22

        location.start()

        if mode.startSpeedKmh <= 0.5 {
            state = .armedStationary
            motion.start()
            statusText = String(localized: "Bereit – Fahrzeug anhalten und beschleunigen", locale: currentLocale)
        } else {
            state = .armedRolling
            statusText = String(format: String(localized: "Bereit – auf %@ beschleunigen", locale: currentLocale), currentUnit.formatted(mode.startSpeedKmh))
        }
    }

    /// Bricht eine laufende/bewaffnete Messung ab. `reason` erlaubt einen
    /// spezifischeren Statustext (z.B. bei Zeitüberschreitung) – ohne
    /// Angabe wird der generische „Abgebrochen"-Text verwendet (z.B. beim
    /// manuellen Antippen von „Abbrechen").
    func cancel(reason: String? = nil) {
        motion.stop()
        location.stop()
        state = .idle
        statusText = reason ?? String(localized: "Abgebrochen", locale: currentLocale)
    }

    private func reset() {
        samples = []
        startTimestamp = nil
        targetReachedTimestamp = nil
        accelSustainCount = 0
        totalDistance = 0
        brakingStartDistance = 0
        topSpeed = 0
        brakingElapsed = 0
        elapsed = 0
        currentSpeedKmh = 0
        lastResult = nil
        gpsAccuracy = -1
        gpsVerticalAccuracy = -1
        previousLocation = nil
        lastKnownAltitude = 0
        altitudeAtStart = nil
        lastKnownCoordinate = nil
    }

    // MARK: - Motion (G-Sensor) – nur für die Start-Erkennung

    private func handleMotion(_ m: CMDeviceMotion) {
        guard state == .armedStationary else { return }

        let ax = m.userAcceleration.x
        let ay = m.userAcceleration.y
        let horizontalMagG = (ax * ax + ay * ay).squareRoot()

        if horizontalMagG > accelTriggerThreshold {
            accelSustainCount += 1
            if accelSustainCount >= requiredSustainSamples {
                triggerStationaryStart(at: Date().timeIntervalSinceReferenceDate)
            }
        } else {
            accelSustainCount = 0
        }
    }

    private func triggerStationaryStart(at timestamp: TimeInterval) {
        motion.stop()
        startTimestamp = timestamp
        altitudeAtStart = lastKnownAltitude
        state = .measuringToTarget
        statusText = String(localized: "Messung läuft…", locale: currentLocale)
        recordSample(timestamp: timestamp, speed: 0, distanceM: 0, altitudeM: 0, latitude: lastKnownCoordinate?.latitude, longitude: lastKnownCoordinate?.longitude, source: "start")
    }

    // MARK: - Location (GPS)

    private func handleLocation(_ loc: CLLocation) {
        gpsAccuracy = loc.horizontalAccuracy
        gpsVerticalAccuracy = loc.verticalAccuracy
        lastKnownAltitude = loc.altitude
        lastKnownCoordinate = loc.coordinate

        let previous = previousLocation
        previousLocation = loc

        guard loc.speed >= 0 else {
            #if DEBUG
            print("[Inertia-Debug] handleLocation: verworfen, loc.speed=\(loc.speed) < 0 (state=\(state))")
            #endif
            return
        }

        let gpsSpeedKmh = loc.speed * 3.6
        let timestamp = loc.timestamp.timeIntervalSinceReferenceDate
        let previousSpeedKmh: Double? = (previous?.speed).flatMap { $0 >= 0 ? $0 * 3.6 : nil }
        let previousTimestamp = previous?.timestamp.timeIntervalSinceReferenceDate

        switch state {
        case .armedRolling:
            currentSpeedKmh = gpsSpeedKmh
            if gpsSpeedKmh >= mode.startSpeedKmh {
                startTimestamp = interpolatedCrossing(
                    prevSpeed: previousSpeedKmh, prevTime: previousTimestamp,
                    curSpeed: gpsSpeedKmh, curTime: timestamp,
                    target: mode.startSpeedKmh
                ) ?? timestamp
                altitudeAtStart = loc.altitude
                state = .measuringToTarget
                statusText = String(localized: "Messung läuft…", locale: currentLocale)
                recordSample(timestamp: timestamp, speed: gpsSpeedKmh, distanceM: totalDistance, altitudeM: 0, latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude, source: "gps")
            }

        case .measuringToTarget, .measuringBraking:
            currentSpeedKmh = gpsSpeedKmh
            if let previous, previous.speed >= 0 {
                let delta = loc.distance(from: previous)
                totalDistance += delta
                #if DEBUG
                print("[Inertia-Debug] +\(String(format: "%.2f", delta))m (prev.speed=\(String(format: "%.2f", previous.speed)), loc.speed=\(String(format: "%.2f", loc.speed))) -> total=\(String(format: "%.2f", totalDistance))m")
                #endif
            } else {
                #if DEBUG
                print("[Inertia-Debug] KEIN Distanz-Zuwachs: previous vorhanden=\(previous != nil), previous.speed=\(previous?.speed.description ?? "nil")")
                #endif
            }
            let altitudeSinceStart = loc.altitude - (altitudeAtStart ?? loc.altitude)
            recordSample(timestamp: timestamp, speed: gpsSpeedKmh, distanceM: totalDistance, altitudeM: altitudeSinceStart, latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude, source: "gps")
            evaluateThresholds(
                previousSpeedKmh: previousSpeedKmh, previousTimestamp: previousTimestamp,
                currentSpeedKmh: gpsSpeedKmh, currentTimestamp: timestamp
            )

        default:
            currentSpeedKmh = gpsSpeedKmh
        }
    }

    // MARK: - Auswertung

    private func recordSample(timestamp: TimeInterval, speed: Double, distanceM: Double, altitudeM: Double, latitude: Double?, longitude: Double?, source: String) {
        guard let start = startTimestamp else { return }
        topSpeed = max(topSpeed, speed)
        samples.append(SpeedSample(t: timestamp - start, speedKmh: speed, distanceM: distanceM, altitudeM: altitudeM, latitude: latitude, longitude: longitude, source: source))
        elapsed = timestamp - start
    }

    /// Lineare Interpolation des Zeitpunkts, an dem die Geschwindigkeit
    /// zwischen zwei GPS-Samples exakt `target` erreicht hat. Liefert `nil`,
    /// wenn kein vorheriges Sample vorliegt oder die Interpolation nicht
    /// eindeutig ist – in dem Fall wird auf den rohen GPS-Zeitstempel
    /// zurückgefallen.
    private func interpolatedCrossing(
        prevSpeed: Double?, prevTime: TimeInterval?,
        curSpeed: Double, curTime: TimeInterval,
        target: Double
    ) -> TimeInterval? {
        guard let prevSpeed, let prevTime, curSpeed != prevSpeed else { return nil }
        let fraction = (target - prevSpeed) / (curSpeed - prevSpeed)
        guard fraction.isFinite, fraction >= 0, fraction <= 1 else { return nil }
        return prevTime + fraction * (curTime - prevTime)
    }

    private func evaluateThresholds(
        previousSpeedKmh: Double?, previousTimestamp: TimeInterval?,
        currentSpeedKmh speedNow: Double, currentTimestamp timestamp: TimeInterval
    ) {
        guard let start = startTimestamp else { return }

        if state == .measuringToTarget, speedNow >= mode.targetSpeedKmh {
            let reached = interpolatedCrossing(
                prevSpeed: previousSpeedKmh, prevTime: previousTimestamp,
                curSpeed: speedNow, curTime: timestamp,
                target: mode.targetSpeedKmh
            ) ?? timestamp
            targetReachedTimestamp = reached
            elapsed = reached - start
            if let brakeTo = mode.brakeToSpeedKmh {
                state = .measuringBraking
                brakingStartDistance = totalDistance
                statusText = brakeTo <= 0.5
                    ? String(localized: "Ziel erreicht – jetzt bremsen", locale: currentLocale)
                    : String(format: String(localized: "Ziel erreicht – auf %@ abbremsen", locale: currentLocale), currentUnit.formatted(brakeTo))
            } else {
                finish()
            }
            return
        }

        if state == .measuringBraking {
            let brakeTarget = mode.brakeToSpeedKmh ?? 0
            if speedNow <= brakeTarget + 0.5 {
                let reached = interpolatedCrossing(
                    prevSpeed: previousSpeedKmh, prevTime: previousTimestamp,
                    curSpeed: speedNow, curTime: timestamp,
                    target: brakeTarget
                ) ?? timestamp
                brakingElapsed = reached - (targetReachedTimestamp ?? reached)
                finish()
                return
            }
        }

        // Sicherheitsabbruch, falls auch nach `safetyTimeoutSeconds` kein
        // Ziel erreicht wird (z.B. GPS-Ausfall oder Fehlauslösung).
        if timestamp - start > Self.safetyTimeoutSeconds {
            cancel(reason: String(localized: "Zeitüberschreitung – Messung abgebrochen", locale: currentLocale))
        }
    }

    private func finish() {
        motion.stop()
        location.stop()
        state = .finished
        statusText = String(localized: "Messung abgeschlossen", locale: currentLocale)

        #if DEBUG
        print("[Inertia-Debug] finish(): totalDistance=\(String(format: "%.2f", totalDistance))m, samples=\(samples.count)")
        #endif

        guard let start = startTimestamp else { return }
        let mainElapsed = (targetReachedTimestamp ?? Date().timeIntervalSinceReferenceDate) - start

        let result = MeasurementResult(
            date: Date(),
            modeName: mode.name,
            startSpeedKmh: mode.startSpeedKmh,
            targetSpeedKmh: mode.targetSpeedKmh,
            elapsedSeconds: mainElapsed,
            brakingSeconds: mode.includesBraking ? brakingElapsed : nil,
            brakingDistanceMeters: mode.includesBraking ? (totalDistance - brakingStartDistance) : nil,
            brakeToSpeedKmh: mode.brakeToSpeedKmh,
            totalDistanceMeters: totalDistance,
            topSpeedKmh: topSpeed,
            samples: samples,
            vehicleDisplayName: selectedVehicleDisplayName,
            vehicleYear: selectedVehicleYear,
            vehicleHorsepowerPS: selectedVehicleHorsepowerPS,
            driveMode: selectedDriveMode,
            notes: selectedNotes
        )

        lastResult = result
        ResultStore.shared.save(result)
    }
}
