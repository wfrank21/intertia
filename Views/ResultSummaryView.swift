import Charts
import CoreLocation
import SwiftUI
import UIKit

struct ResultSummaryView: View {
    /// Als `@State` statt `let` gehalten, damit sich nach dem Bearbeiten
    /// über `ResultEditView` (Fahrzeug/Fahrmodus/Notiz nachträglich ändern)
    /// sofort die aktuelle Fassung anzeigt, ohne dass die aufrufende View
    /// (z.B. `HistoryView`) neu geladen werden müsste.
    @State private var result: MeasurementResult

    @AppStorage("speedUnit") private var speedUnit: SpeedUnit = .kmh
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .auto

    /// Aktuell im Diagramm ausgewähltes Sample (per Antippen/Ziehen), oder
    /// `nil`, wenn keine Auswahl aktiv ist.
    @State private var selectedSample: SpeedSample?
    @State private var showEditSheet = false
    /// Zuletzt gerendertes Bild der `ResultShareCardView`, nur zu
    /// Diagnosezwecken/Wiederverwendung gehalten – die Präsentation selbst
    /// läuft direkt über `ShareSheetPresenter` (siehe `shareResult()`), nicht
    /// über ein SwiftUI-`.sheet`.
    @State private var shareImage: UIImage?

    private var locale: Locale { appLanguage.resolvedLocale }

    init(result: MeasurementResult) {
        _result = State(initialValue: result)
    }

    /// Aus den Geschwindigkeits-Samples abgeleitete Beschleunigungswerte
    /// (m/s²), einmal pro View-Aufbau berechnet.
    private var accelerationSamples: [AccelerationSample] { result.accelerationSamples }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            titleSection
            statsSection
            notesSection

            if !result.samples.isEmpty {
                Text("Zum Anzeigen der Detailwerte auf das Diagramm tippen oder ziehen.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                chart

                if !accelerationSamples.isEmpty {
                    accelerationChart
                }

                if let selectedSample {
                    selectionDetail(selectedSample)
                        .transition(.opacity)
                }
            }

            if result.hasRouteData {
                routeMapSection
            }
        }
        .font(.subheadline)
        .foregroundStyle(.primary)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .animation(.easeInOut(duration: 0.15), value: selectedSample)
        .sheet(isPresented: $showEditSheet) {
            ResultEditView(result: result) { updated in
                result = updated
            }
        }
    }

    /// Rendert `ResultShareCardView` über `ImageRenderer` (iOS 16+) in ein
    /// `UIImage` und öffnet direkt darauf das Share Sheet über
    /// `ShareSheetPresenter` (UIKit-Präsentation statt SwiftUI-`.sheet`,
    /// siehe Kommentar in `ShareSheet.swift` – vermeidet den grauen Screen
    /// beim ersten Antippen). Wird synchron auf dem Main-Thread ausgeführt
    /// (SwiftUI-Rendering ist ohnehin an den Main-Thread gebunden), bei der
    /// kompakten Kartengröße dieser App ist das schnell genug, um keinen
    /// sichtbaren Ruckler zu verursachen.
    private func shareResult() {
        let card = ResultShareCardView(result: result, speedUnit: speedUnit, locale: locale)
        let renderer = ImageRenderer(content: card)
        renderer.scale = UIScreen.main.scale
        if let image = renderer.uiImage {
            shareImage = image
            ShareSheetPresenter.present(items: [image])
        }
    }

    /// Titel, Fahrzeug und Fahrmodus. In eine eigene Sub-View ausgelagert,
    /// damit der Swift-Compiler `body` als Ganzes noch in angemessener Zeit
    /// typprüfen kann (SwiftUI-ViewBuilder-Ausdrücke mit vielen bedingten
    /// Zweigen und verschachtelten `String(format:)`-Aufrufen können sonst
    /// zu "unable to type-check this expression" führen).
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(result.displayName(unit: speedUnit))
                    .font(.headline)
                Spacer()
                Button {
                    shareResult()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Button {
                    showEditSheet = true
                } label: {
                    Image(systemName: "pencil.circle")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            if result.vehicleDisplayName != nil || driveModeText != nil {
                HStack(spacing: 8) {
                    if let vehicleDisplayName = result.vehicleDisplayName {
                        Text(vehicleDisplayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    if let driveModeText {
                        driveModeBadge(driveModeText)
                    }
                }
            }

            Text(String(format: String(localized: "Zeit: %.2f s", locale: locale), result.elapsedSeconds))
                .font(.title3.bold())
        }
    }

    /// `nil`, wenn kein Fahrmodus eingegeben wurde oder er nur aus
    /// Leerzeichen besteht.
    private var driveModeText: String? {
        guard let driveMode = result.driveMode, !driveMode.isEmpty else { return nil }
        return driveMode
    }

    /// Auffälliges Badge für den Fahrmodus (z.B. "Sport+"), statt eines
    /// klein gedruckten Zusatztexts – der Fahrmodus ist für den Nutzer eine
    /// der wichtigsten Angaben beim Vergleichen mehrerer Messungen.
    private func driveModeBadge(_ text: String) -> some View {
        Label(text, systemImage: "steeringwheel")
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.accentColor, in: Capsule())
    }

    /// Zeit-, Brems-, Strecken-, Beschleunigungs- und Höhenwerte. Ebenfalls
    /// aus `body` ausgelagert (siehe `titleSection`).
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let braking = result.brakingSeconds {
                if let brakeTo = result.brakeToSpeedKmh, brakeTo > 0.5 {
                    Text(String(format: String(localized: "Bremsphase (bis %@): %.2f s", locale: locale), speedUnit.formatted(brakeTo), braking))
                } else {
                    Text(String(format: String(localized: "Bremsphase: %.2f s", locale: locale), braking))
                }
            }
            if let brakingDist = result.brakingDistanceMeters {
                Text(String(format: String(localized: "Bremsweg: %.1f m", locale: locale), brakingDist))
            }

            Text(String(format: String(localized: "Strecke gesamt: %.1f m", locale: locale), result.totalDistanceMeters))
            Text(String(format: String(localized: "Höchstgeschwindigkeit: %@", locale: locale), speedUnit.formatted(result.topSpeedKmh)))

            if let maxAccel = result.maxAccelerationMS2 {
                Text(String(format: String(localized: "Max. Beschleunigung: %.2f m/s²", locale: locale), maxAccel))
            }
            if let maxDecel = result.maxDecelerationMS2 {
                Text(String(format: String(localized: "Max. Verzögerung: %.2f m/s²", locale: locale), maxDecel))
            }

            if result.hasElevationData {
                Text(String(format: String(localized: "Höhenmeter: +%.1f m / -%.1f m", locale: locale), result.elevationGainM, result.elevationLossM))
            }
        }
    }

    /// Freie Notiz zur Messung (siehe `MeasurementResult.notes`), nur
    /// sichtbar, wenn eine gesetzt ist. `@ViewBuilder`, damit hier direkt
    /// bedingt `nil`/`Text` zurückgegeben werden kann, ohne `body` selbst
    /// mit einer weiteren `if`-Verzweigung zu belasten (siehe `titleSection`).
    @ViewBuilder
    private var notesSection: some View {
        if let notes = result.notes, !notes.isEmpty {
            Text(notes)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    /// Für die Diagrammdarstellung verdichtete Samples (siehe
    /// `MeasurementResult.displaySamples`), damit die Linie nicht nur alle
    /// ~1s (GPS-Update-Rate) einen sichtbaren Punkt hat.
    private var displaySamples: [SpeedSample] { result.displaySamples }

    private var chart: some View {
        Chart {
            ForEach(displaySamples) { sample in
                LineMark(
                    x: .value("Zeit", sample.t),
                    y: .value("Geschwindigkeit", speedUnit.fromKmh(sample.speedKmh))
                )
                .interpolationMethod(.catmullRom)
            }

            if let selectedSample {
                RuleMark(x: .value("Zeit", selectedSample.t))
                    .foregroundStyle(Color.secondary.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

                PointMark(
                    x: .value("Zeit", selectedSample.t),
                    y: .value("Geschwindigkeit", speedUnit.fromKmh(selectedSample.speedKmh))
                )
                .foregroundStyle(.blue)
                .symbolSize(70)
            }
        }
        .chartXAxisLabel("Sekunden")
        .chartYAxisLabel(speedUnit.symbol)
        .frame(height: 160)
        .padding(.top, 4)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                selectSample(at: value.location, proxy: proxy, geometry: geometry)
                            }
                    )
                    .onTapGesture { location in
                        selectSample(at: location, proxy: proxy, geometry: geometry)
                    }
            }
        }
    }

    /// Kleines zweites Diagramm unterhalb der Geschwindigkeitskurve: zeigt
    /// die aus den GPS-Samples abgeleitete Beschleunigung (m/s²) über der
    /// Zeit, mit einer Null-Linie zur Orientierung zwischen Beschleunigen
    /// (positiv) und Bremsen/Verzögern (negativ).
    private var accelerationChart: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Beschleunigung")
                .font(.caption)
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

                if let selectedSample, let nearest = nearestAcceleration(to: selectedSample.t) {
                    PointMark(
                        x: .value("Zeit", nearest.t),
                        y: .value("Beschleunigung", nearest.accelMS2)
                    )
                    .foregroundStyle(.orange)
                    .symbolSize(60)
                }
            }
            .chartXAxisLabel("Sekunden")
            .chartYAxisLabel("m/s²")
            .frame(height: 100)
        }
        .padding(.top, 8)
    }

    /// Zeigt die gefahrene Strecke (aus den echten, nicht interpolierten
    /// GPS-Samples) als Linie auf einer Karte, mit Markern für Start und
    /// Ziel. Nur sichtbar, wenn genug echte Koordinaten vorliegen
    /// (`MeasurementResult.hasRouteData`).
    private var routeMapSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Strecke auf der Karte")
                .font(.caption)
                .foregroundStyle(.secondary)

            RouteMapView(coordinates: result.routeCoordinates)
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(.top, 8)
    }

    /// Findet zum X-Wert (Zeit) an der Tipp-/Zieh-Position das nächstgelegene
    /// Sample aus `displaySamples` (echte GPS-Samples plus dazwischen linear
    /// interpolierte Zwischenpunkte) und wählt es aus – dadurch fühlt sich
    /// das Ziehen über das Diagramm flüssig an, statt nur alle ~1s (GPS-
    /// Update-Rate) auf einen neuen Wert zu springen.
    private func selectSample(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        let origin = geometry[proxy.plotAreaFrame].origin
        let xPosition = location.x - origin.x
        guard let time: Double = proxy.value(atX: xPosition) else { return }
        selectedSample = displaySamples.min { abs($0.t - time) < abs($1.t - time) }
    }

    private func nearestAcceleration(to time: Double) -> AccelerationSample? {
        accelerationSamples.min { abs($0.t - time) < abs($1.t - time) }
    }

    private func selectionDetail(_ sample: SpeedSample) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 10) {
            detailItem(labelKey: "Zeit", value: String(format: "%.2f s", sample.t))
            detailItem(labelKey: "Geschwindigkeit", value: speedUnit.formatted(sample.speedKmh))
            detailItem(labelKey: "Strecke", value: String(format: "%.1f m", sample.distanceM))
            detailItem(labelKey: "Beschleunigung", value: accelerationDisplay(near: sample.t))
            if result.hasElevationData {
                detailItem(labelKey: "Höhenänderung", value: String(format: "%+.1f m", sample.altitudeM))
            }
        }
        .padding(10)
        .padding(.trailing, 20)
        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        .overlay(alignment: .topTrailing) {
            Button {
                selectedSample = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(6)
        }
    }

    private func accelerationDisplay(near time: Double) -> String {
        guard let accel = nearestAcceleration(to: time)?.accelMS2 else { return "–" }
        return String(format: "%.2f m/s²", accel)
    }

    private func detailItem(labelKey: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(labelKey)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.bold())
                .monospacedDigit()
        }
    }
}

/// Baut Preview-Beispieldaten. Bewusst außerhalb des `#Preview`-Makros als
/// eigene Funktion mit expliziten Zwischenwerten, statt alles als einen
/// einzigen verschachtelten Ausdruck zu schreiben – sonst kann der Swift-
/// Compiler bei der Typprüfung sehr langsam werden oder mit "unable to
/// type-check this expression in reasonable time" abbrechen.
private func previewSample(_ i: Int) -> SpeedSample {
    let t: TimeInterval = Double(i) * 0.27
    let speed: Double = Double(i) * 5
    let distance: Double = Double(i * i) * 0.9
    let altitude: Double = Double(i) * 0.15
    let lat: Double = 48.1351 + Double(i) * 0.0003
    let lon: Double = 11.5820 + Double(i) * 0.0002
    return SpeedSample(t: t, speedKmh: speed, distanceM: distance, altitudeM: altitude, latitude: lat, longitude: lon, source: "gps")
}

private func previewResult() -> MeasurementResult {
    let samples: [SpeedSample] = (0...20).map { previewSample($0) }
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
        driveMode: "Sport+",
        notes: "Testfahrt bei Regen, kalter Motor"
    )
}

#Preview {
    ResultSummaryView(result: previewResult())
        .padding()
}
