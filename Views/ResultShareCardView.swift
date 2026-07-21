import Charts
import SwiftUI

/// Kompakte, für den Bild-Export optimierte Zusammenfassung eines
/// Messergebnisses. Wird nicht direkt angezeigt, sondern über
/// `ImageRenderer` (siehe `ResultSummaryView.renderShareImage()`) in ein
/// `UIImage` gerendert und anschließend über das Share Sheet geteilt (z.B.
/// per Nachricht, AirDrop oder Sichern in Fotos). Bewusst als eigene,
/// einfachere View statt Wiederverwendung von `ResultSummaryView`: Die
/// interaktiven Elemente dort (Tap/Drag-Auswahl, Bearbeiten-Button, Karte)
/// ergeben in einem statischen Bild keinen Sinn.
struct ResultShareCardView: View {
    let result: MeasurementResult
    let speedUnit: SpeedUnit
    let locale: Locale

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            Text(result.displayName(unit: speedUnit))
                .font(.title2.bold())

            timeRow

            vehicleAndDriveModeRow

            if !result.samples.isEmpty {
                shareChart
            }

            if !accelerationSamples.isEmpty {
                shareAccelerationChart
            }

            statsGrid

            Spacer(minLength: 0)

            Text(result.date.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 400, height: 850, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [Color(.systemBackground), Color.accentColor.opacity(0.1)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .foregroundStyle(.primary)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "speedometer")
                .foregroundStyle(Color.accentColor)
            Text("Inertia")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var vehicleAndDriveModeRow: some View {
        if result.vehicleDisplayName != nil || driveModeText != nil {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    if let vehicleDisplayName = result.vehicleDisplayName {
                        Text(vehicleDisplayName)
                            .font(.headline)
                    }
                    if let driveModeText {
                        Text(driveModeText)
                            .font(.subheadline.weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(Color.accentColor, in: Capsule())
                            .foregroundStyle(.white)
                    }
                }
                if let vehicleDetailText {
                    Text(vehicleDetailText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var driveModeText: String? {
        guard let driveMode = result.driveMode, !driveMode.isEmpty else { return nil }
        return driveMode
    }

    /// Baujahr und PS des Fahrzeugs (`MeasurementResult.vehicleYear`/
    /// `.vehicleHorsepowerPS`), z.B. "2021 · 510 PS". `nil`, wenn keine der
    /// beiden Angaben vorhanden ist.
    ///
    /// Fällt auf das aktuell in der Fahrzeugliste hinterlegte Fahrzeug
    /// zurück, falls die eingefrorenen Felder `nil` sind – das betrifft vor
    /// allem ältere, bereits vor Einführung dieses Felds gespeicherte
    /// Messungen. Nur eine Anzeige-Fallback, es wird nichts zurück in die
    /// gespeicherte Messung geschrieben.
    private var vehicleDetailText: String? {
        let year = result.vehicleYear ?? fallbackVehicle?.year
        let hp = result.vehicleHorsepowerPS ?? fallbackVehicle?.horsepowerPS
        var parts: [String] = []
        if let year {
            parts.append(String(year))
        }
        if let hp {
            parts.append(String(format: String(localized: "%d PS", locale: locale), hp))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var fallbackVehicle: Vehicle? {
        guard let name = result.vehicleDisplayName, !name.isEmpty else { return nil }
        return VehicleStore.shared.vehicles.first { $0.displayName == name }
    }

    /// Zeitanzeige im Digitaluhr-Look (links) plus analoges Stoppuhr-
    /// Zifferblatt (rechts, `StopwatchDialView`), das dieselbe Zeit noch
    /// einmal visuell als Zeigerausschlag zeigt. iOS bringt keine echte
    /// Siebensegment-/LCD-Systemschriftart mit; der "Digitaluhr"-Effekt
    /// entsteht hier über eine monospaced Systemschrift mit fester
    /// Zeichenbreite auf dunklem, abgerundetem Anzeige-Hintergrund.
    private var timeRow: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Zeit")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(String(format: "%.2f", result.elapsedSeconds))
                    .font(.system(size: 34, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 8))

                Text("Sekunden")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            StopwatchDialView(seconds: result.elapsedSeconds)
        }
    }

    /// Aus den Geschwindigkeits-Samples abgeleitete Beschleunigungswerte,
    /// siehe `MeasurementResult.accelerationSamples`.
    private var accelerationSamples: [AccelerationSample] { result.accelerationSamples }

    /// Nicht-interaktive Variante des Geschwindigkeitsdiagramms (kein
    /// Tap/Drag), aber mit sichtbarer Achsenbeschriftung (Sekunden /
    /// Geschwindigkeitseinheit), damit die Skala im geteilten Bild auch
    /// ohne die App erkennbar ist.
    private var shareChart: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Geschwindigkeit")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Chart(result.displaySamples) { sample in
                LineMark(
                    x: .value("Zeit", sample.t),
                    y: .value("Geschwindigkeit", speedUnit.fromKmh(sample.speedKmh))
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Color.accentColor)
            }
            .chartXAxisLabel("Sekunden")
            .chartYAxisLabel(speedUnit.symbol)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) {
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel()
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) {
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel()
                }
            }
            .chartPlotStyle { plot in
                plot.background(Color.secondary.opacity(0.06))
            }
            .font(.system(size: 9))
            .frame(height: 130)
        }
    }

    /// Zweites, kleineres Diagramm mit der aus den Geschwindigkeits-Samples
    /// abgeleiteten Beschleunigung (m/s²) über der Zeit, inkl. Null-Linie
    /// zur Orientierung zwischen Beschleunigen (positiv) und Bremsen/
    /// Verzögern (negativ) – analog zum Diagramm in `ResultSummaryView`.
    private var shareAccelerationChart: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Beschleunigung")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Chart {
                RuleMark(y: .value("Null", 0))
                    .foregroundStyle(Color.secondary.opacity(0.35))

                ForEach(accelerationSamples) { sample in
                    LineMark(
                        x: .value("Zeit", sample.t),
                        y: .value("Beschleunigung", sample.accelMS2)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(.orange)
                }
            }
            .chartXAxisLabel("Sekunden")
            .chartYAxisLabel("m/s²")
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) {
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel()
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) {
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel()
                }
            }
            .chartPlotStyle { plot in
                plot.background(Color.secondary.opacity(0.06))
            }
            .font(.system(size: 9))
            .frame(height: 110)
        }
        .padding(.top, 4)
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 12) {
            statItem(label: String(localized: "Strecke", locale: locale), value: String(format: "%.1f m", result.totalDistanceMeters))
            statItem(label: String(localized: "Höchstgeschwindigkeit", locale: locale), value: speedUnit.formatted(result.topSpeedKmh))
            if let maxAccel = result.maxAccelerationMS2 {
                statItem(label: String(localized: "Max. Beschleunigung", locale: locale), value: String(format: "%.2f m/s²", maxAccel))
            }
            if result.hasElevationData {
                statItem(label: String(localized: "Höhenmeter", locale: locale), value: String(format: "+%.1f / -%.1f m", result.elevationGainM, result.elevationLossM))
            }
        }
    }

    private func statItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.bold())
                .monospacedDigit()
        }
    }
}

/// Eigene, minimale Preview-Beispieldaten statt Wiederverwendung von
/// `previewResult()` aus `ResultSummaryView.swift`: Diese ist dort bewusst
/// `private` (dateiweit), also aus dieser Datei nicht erreichbar.
private func shareCardPreviewResult() -> MeasurementResult {
    let samples: [SpeedSample] = (0...20).map { i in
        SpeedSample(t: Double(i) * 0.27, speedKmh: Double(i) * 5, distanceM: Double(i * i) * 0.9, altitudeM: 0, source: "gps")
    }
    return MeasurementResult(
        date: .now,
        modeName: "0–100 km/h",
        startSpeedKmh: 0,
        targetSpeedKmh: 100,
        elapsedSeconds: 5.43,
        brakingSeconds: nil,
        brakingDistanceMeters: nil,
        brakeToSpeedKmh: nil,
        totalDistanceMeters: 92.3,
        topSpeedKmh: 101.2,
        samples: samples,
        vehicleDisplayName: "BMW M3",
        vehicleYear: 2021,
        vehicleHorsepowerPS: 510,
        driveMode: "Sport+",
        notes: nil
    )
}

#Preview {
    ResultShareCardView(result: shareCardPreviewResult(), speedUnit: .kmh, locale: .current)
}
