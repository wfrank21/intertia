import SwiftUI

struct MeasurementView: View {
    @StateObject private var engine = MeasurementEngine()
    @ObservedObject private var vehicleStore = VehicleStore.shared
    @ObservedObject private var customModeStore = CustomModeStore.shared
    @AppStorage("speedUnit") private var speedUnit: SpeedUnit = .kmh
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .auto

    private var locale: Locale { appLanguage.resolvedLocale }

    @State private var selectedStandard: StandardModeOption = .zeroToHundred
    @State private var customFrom: Double = 60      // immer in km/h gehalten
    @State private var customTo: Double = 120        // immer in km/h gehalten
    @State private var customIncludesBraking: Bool = false
    @State private var customBrakeTo: Double = 0     // immer in km/h gehalten
    @FocusState private var focusedField: CustomField?
    @State private var showGPSDetail = false

    /// `id` des zuletzt per Chip ausgewählten gespeicherten Modus (siehe
    /// `savedPresetsRow`), nur zur optischen Hervorhebung. Wird zurückgesetzt,
    /// sobald der Nutzer die Werte manuell ändert oder einen anderen
    /// Hauptmodus wählt.
    @State private var selectedPresetID: UUID?
    @State private var showSavePresetAlert = false
    @State private var newPresetName: String = ""
    @State private var presetPendingDeletion: CustomModePreset?

    /// Für die aktuelle Messung ausgewähltes Fahrzeug, standardmäßig das in
    /// der Fahrzeugliste als Standard markierte (siehe `didInitVehicleSelection`).
    @State private var selectedVehicle: Vehicle?
    @State private var didInitVehicleSelection = false
    /// Frei eingegebener Fahrmodus (z.B. "Sport+", "Winterreifen").
    @State private var driveModeText: String = ""
    /// Freie Notiz zur Messung (z.B. Bedingungen), bereits vor dem Start
    /// eintragbar – landet unverändert in `MeasurementResult.notes` und
    /// lässt sich später über `ResultEditView` auch noch ändern.
    @State private var notesText: String = ""

    enum CustomField: Hashable {
        case from, to, brakeTo, driveMode, notes
    }

    enum StandardModeOption: CaseIterable, Identifiable, Hashable {
        case zeroToHundred
        case zeroToHundredToZero
        case hundredToTwoHundred
        case custom

        var id: Self { self }

        var mode: MeasurementMode? {
            switch self {
            case .zeroToHundred: return .zeroToHundred
            case .zeroToHundredToZero: return .zeroToHundredToZero
            case .hundredToTwoHundred: return .hundredToTwoHundred
            case .custom: return nil
            }
        }

        func label(unit: SpeedUnit) -> String {
            if let mode {
                return mode.displayName(unit: unit)
            } else {
                return String(localized: "Frei", locale: AppLanguage.current.resolvedLocale)
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    speedGauge
                    modePicker
                    vehicleSection
                    statusSection
                    controlButton

                    if engine.state == .finished, let result = engine.lastResult {
                        ResultSummaryView(result: result)
                    }
                }
                .padding()
            }
            .navigationTitle("Inertia")
            .onAppear {
                engine.requestPermissions()
                if !didInitVehicleSelection {
                    selectedVehicle = vehicleStore.defaultVehicle
                    didInitVehicleSelection = true
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Fertig") { focusedField = nil }
                }
            }
        }
    }

    private var speedGauge: some View {
        VStack(spacing: 4) {
            Text(speedUnit.roundedString(engine.currentSpeedKmh))
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(speedUnit.symbol)
                .foregroundStyle(.secondary)
            Text(String(format: "%.2f s", engine.elapsed))
                .font(.title2.monospacedDigit())
                .foregroundStyle(.blue)
        }
        .padding(.top, 8)
    }

    private var modePicker: some View {
        VStack(spacing: 12) {
            Picker("Modus", selection: $selectedStandard) {
                ForEach(StandardModeOption.allCases) { option in
                    Text(option.label(unit: speedUnit)).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .disabled(isRunning)
            .onChange(of: selectedStandard) { _ in selectedPresetID = nil }

            if !customModeStore.presets.isEmpty {
                savedPresetsRow
            }

            if selectedStandard == .custom {
                VStack(spacing: 10) {
                    speedField(titleKey: "Von", kmhBinding: $customFrom, field: .from)
                    speedField(titleKey: "Bis", kmhBinding: $customTo, field: .to)

                    Toggle("Inkl. Bremsphase (xxx–xxx–xxx)", isOn: $customIncludesBraking)

                    if customIncludesBraking {
                        speedField(titleKey: "Bremsen bis", kmhBinding: $customBrakeTo, field: .brakeTo)
                    }

                    if let message = customValidationMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    if !isRunning {
                        Button {
                            newPresetName = ""
                            showSavePresetAlert = true
                        } label: {
                            Label("Diesen Modus speichern", systemImage: "bookmark")
                                .font(.caption.weight(.semibold))
                        }
                        .disabled(customValidationMessage != nil)
                    }
                }
                .font(.subheadline)
                .disabled(isRunning)
            }
        }
        .alert(String(localized: "Modus speichern", locale: locale), isPresented: $showSavePresetAlert) {
            TextField(String(localized: "Name (optional)", locale: locale), text: $newPresetName)
            Button(String(localized: "Speichern", locale: locale)) { saveCurrentAsPreset() }
            Button(String(localized: "Abbrechen", locale: locale), role: .cancel) {}
        } message: {
            Text(String(format: String(localized: "Speichert %@ als Schnellauswahl für zukünftige Messungen.", locale: locale), currentCustomRangeLabel))
        }
    }

    /// Horizontale Schnellauswahl der vom Nutzer gespeicherten Freimodi
    /// (z.B. "50–100 km/h"), damit häufig genutzte Geschwindigkeitsbereiche
    /// nicht jedes Mal neu eingegeben werden müssen. Tippen wählt den
    /// „Frei"-Modus und übernimmt die gespeicherten Werte; langes Drücken
    /// bietet an, das Preset zu löschen.
    private var savedPresetsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(customModeStore.presets) { preset in
                    Button {
                        applyPreset(preset)
                    } label: {
                        Text(preset.displayName(unit: speedUnit))
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                selectedPresetID == preset.id ? Color.accentColor : Color.secondary.opacity(0.15),
                                in: Capsule()
                            )
                            .foregroundStyle(selectedPresetID == preset.id ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                    .disabled(isRunning)
                    .onLongPressGesture {
                        presetPendingDeletion = preset
                    }
                }
            }
        }
        .confirmationDialog(
            String(localized: "Gespeicherten Modus löschen?", locale: locale),
            isPresented: Binding(
                get: { presetPendingDeletion != nil },
                set: { if !$0 { presetPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(String(localized: "Löschen", locale: locale), role: .destructive) {
                if let preset = presetPendingDeletion {
                    customModeStore.delete(preset)
                    if selectedPresetID == preset.id { selectedPresetID = nil }
                }
                presetPendingDeletion = nil
            }
            Button(String(localized: "Abbrechen", locale: locale), role: .cancel) {
                presetPendingDeletion = nil
            }
        }
    }

    private func applyPreset(_ preset: CustomModePreset) {
        selectedStandard = .custom
        customFrom = preset.fromKmh
        customTo = preset.toKmh
        customIncludesBraking = preset.includesBraking
        customBrakeTo = preset.brakeToKmh
        selectedPresetID = preset.id
    }

    private func saveCurrentAsPreset() {
        let preset = CustomModePreset(
            name: newPresetName.trimmingCharacters(in: .whitespaces),
            fromKmh: customFrom,
            toKmh: customTo,
            includesBraking: customIncludesBraking,
            brakeToKmh: customIncludesBraking ? customBrakeTo : 0
        )
        customModeStore.add(preset)
        selectedPresetID = preset.id
    }

    /// Anzeigetext des aktuell im „Frei"-Modus eingestellten
    /// Geschwindigkeitsbereichs, für die Bestätigungsmeldung beim Speichern.
    private var currentCustomRangeLabel: String {
        customIncludesBraking
            ? MeasurementMode.custom(from: customFrom, to: customTo, brakeTo: customBrakeTo).displayName(unit: speedUnit)
            : MeasurementMode.custom(from: customFrom, to: customTo).displayName(unit: speedUnit)
    }

    /// Eine Zeile mit Label, numerischem Textfeld (in der aktuell gewählten
    /// Einheit) und Einheiten-Symbol. Der übergebene `kmhBinding` bleibt
    /// intern immer in km/h – die Umrechnung passiert nur für die Anzeige.
    private func speedField(titleKey: LocalizedStringKey, kmhBinding: Binding<Double>, field: CustomField) -> some View {
        HStack {
            Text(titleKey)
            Spacer()
            TextField("", value: unitBinding(for: kmhBinding), format: .number.precision(.fractionLength(0)))
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 64)
                .focused($focusedField, equals: field)
                .textFieldStyle(.roundedBorder)
            Text(speedUnit.symbol)
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .leading)
        }
    }

    /// Erzeugt aus einem intern in km/h gehaltenen `@State`-Binding eine
    /// Sicht in der aktuell gewählten Anzeigeeinheit, sodass das Textfeld in
    /// km/h oder mph bedient werden kann, ohne den gespeicherten Wert
    /// (immer km/h) umzudeuten.
    private func unitBinding(for kmhBinding: Binding<Double>) -> Binding<Double> {
        Binding(
            get: { speedUnit.fromKmh(kmhBinding.wrappedValue) },
            set: { kmhBinding.wrappedValue = speedUnit.toKmh(max(0, $0)) }
        )
    }

    /// Validiert die frei eingegebenen Geschwindigkeiten (nur relevant bei
    /// laufender Texteingabe, nicht bei den festen Standard-Modi). `nil`
    /// bedeutet: Eingabe ist plausibel.
    private var customValidationMessage: String? {
        if customTo <= customFrom {
            return String(localized: "„Bis“ muss größer als „Von“ sein.", locale: locale)
        }
        if customIncludesBraking, customBrakeTo >= customTo {
            return String(localized: "„Bremsen bis“ muss kleiner als „Bis“ sein.", locale: locale)
        }
        return nil
    }

    /// Fahrzeugauswahl (falls Fahrzeuge angelegt sind) und Freitextfeld für
    /// den Fahrmodus, vor Messstart editierbar. Wird an `MeasurementEngine.arm`
    /// übergeben und landet unverändert im gespeicherten Ergebnis.
    private var vehicleSection: some View {
        VStack(spacing: 10) {
            if !vehicleStore.vehicles.isEmpty {
                Picker("Fahrzeug", selection: $selectedVehicle) {
                    Text("Kein Fahrzeug").tag(Vehicle?.none)
                    ForEach(vehicleStore.vehicles) { vehicle in
                        Text(vehicle.displayName).tag(Optional(vehicle))
                    }
                }
                .disabled(isRunning)
            }

            HStack(spacing: 8) {
                Image(systemName: "steeringwheel")
                    .foregroundStyle(Color.accentColor)
                TextField(String(localized: "Fahrmodus (z.B. Sport+)", locale: locale), text: $driveModeText)
                    .focused($focusedField, equals: .driveMode)
                    .disabled(isRunning)
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.secondary.opacity(0.12), in: Capsule())

            HStack(spacing: 8) {
                Image(systemName: "note.text")
                    .foregroundStyle(Color.accentColor)
                TextField(String(localized: "Notiz (optional)", locale: locale), text: $notesText)
                    .focused($focusedField, equals: .notes)
                    .disabled(isRunning)
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.secondary.opacity(0.12), in: Capsule())
        }
    }

    private var statusSection: some View {
        VStack(spacing: 4) {
            Text(engine.statusText)
                .font(.headline)
                .multilineTextAlignment(.center)
            if engine.gpsAccuracy > 0 {
                GPSSignalBarsView(
                    horizontalAccuracy: engine.gpsAccuracy,
                    verticalAccuracy: engine.gpsVerticalAccuracy,
                    showDetail: $showGPSDetail
                )
            }
        }
        .sheet(isPresented: $showGPSDetail) {
            GPSDetailView(horizontalAccuracy: engine.gpsAccuracy, verticalAccuracy: engine.gpsVerticalAccuracy)
        }
    }

    private var controlButton: some View {
        Group {
            if engine.state == .idle || engine.state == .finished {
                Button {
                    let trimmedDriveMode = driveModeText.trimmingCharacters(in: .whitespaces)
                    let trimmedNotes = notesText.trimmingCharacters(in: .whitespacesAndNewlines)
                    engine.arm(
                        mode: currentMode(),
                        vehicleDisplayName: selectedVehicle?.displayName,
                        vehicleYear: selectedVehicle?.year,
                        vehicleHorsepowerPS: selectedVehicle?.horsepowerPS,
                        driveMode: trimmedDriveMode.isEmpty ? nil : trimmedDriveMode,
                        notes: trimmedNotes.isEmpty ? nil : trimmedNotes
                    )
                } label: {
                    Label("Start", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(selectedStandard == .custom && customValidationMessage != nil)
            } else {
                Button(role: .destructive) {
                    engine.cancel()
                } label: {
                    Label("Abbrechen", systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
    }

    private var isRunning: Bool {
        engine.state != .idle && engine.state != .finished
    }

    private func currentMode() -> MeasurementMode {
        switch selectedStandard {
        case .zeroToHundred: return .zeroToHundred
        case .zeroToHundredToZero: return .zeroToHundredToZero
        case .hundredToTwoHundred: return .hundredToTwoHundred
        case .custom:
            if customIncludesBraking {
                return .custom(from: customFrom, to: customTo, brakeTo: customBrakeTo)
            } else {
                return .custom(from: customFrom, to: customTo)
            }
        }
    }
}

#Preview {
    MeasurementView()
}
