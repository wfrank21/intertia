import SwiftUI

/// Formular zum nachträglichen Bearbeiten eines bereits gespeicherten
/// Ergebnisses: Fahrzeug, Fahrmodus und eine freie Notiz lassen sich hier
/// auch nach der Messung noch setzen oder ändern – z.B. wenn beim
/// Messstart vergessen wurde, ein Fahrzeug auszuwählen, oder um im
/// Nachhinein Bedingungen zur Fahrt zu notieren.
///
/// Das Fahrzeug wird – wie beim Messstart – nur als eingefrorener
/// Anzeigename (`Vehicle.displayName`) gespeichert, nicht als Referenz auf
/// ein bestimmtes `Vehicle`. Zur Auswahl stehen daher die Anzeigenamen der
/// aktuell in der Fahrzeugliste vorhandenen Fahrzeuge.
struct ResultEditView: View {
    let result: MeasurementResult
    /// Wird nach erfolgreichem Speichern mit dem aktualisierten Ergebnis
    /// aufgerufen, damit die aufrufende View (z.B. `ResultSummaryView`)
    /// sofort den neuen Stand anzeigen kann, ohne auf einen Reload aus dem
    /// `ResultStore` warten zu müssen.
    let onSave: (MeasurementResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var vehicleStore = VehicleStore.shared
    @ObservedObject private var resultStore = ResultStore.shared

    @State private var selectedVehicleName: String
    @State private var driveModeText: String
    @State private var notesText: String

    private var locale: Locale { AppLanguage.current.resolvedLocale }

    init(result: MeasurementResult, onSave: @escaping (MeasurementResult) -> Void) {
        self.result = result
        self.onSave = onSave
        _selectedVehicleName = State(initialValue: result.vehicleDisplayName ?? "")
        _driveModeText = State(initialValue: result.driveMode ?? "")
        _notesText = State(initialValue: result.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Fahrzeug", selection: $selectedVehicleName) {
                        Text("Kein Fahrzeug").tag("")
                        ForEach(vehicleStore.vehicles) { vehicle in
                            Text(vehicle.displayName).tag(vehicle.displayName)
                        }
                    }
                }

                Section {
                    TextField(String(localized: "Fahrmodus (z.B. Sport+)", locale: locale), text: $driveModeText)
                }

                Section {
                    TextField(String(localized: "z.B. Bedingungen, Strecke, Reifen …", locale: locale), text: $notesText, axis: .vertical)
                        .lineLimit(3...8)
                } header: {
                    Text("Notiz")
                }
            }
            .navigationTitle(String(localized: "Ergebnis bearbeiten", locale: locale))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { save() }
                }
            }
        }
    }

    private func save() {
        var updated = result
        updated.vehicleDisplayName = selectedVehicleName.isEmpty ? nil : selectedVehicleName
        // Baujahr/PS werden – wie der Anzeigename – zum Zeitpunkt der
        // Auswahl eingefroren. Bei "Kein Fahrzeug" (leerer Name) oder falls
        // das Fahrzeug inzwischen gelöscht wurde, bleiben sie leer.
        let matchedVehicle = vehicleStore.vehicles.first { $0.displayName == selectedVehicleName }
        updated.vehicleYear = matchedVehicle?.year
        updated.vehicleHorsepowerPS = matchedVehicle?.horsepowerPS

        let trimmedDriveMode = driveModeText.trimmingCharacters(in: .whitespaces)
        updated.driveMode = trimmedDriveMode.isEmpty ? nil : trimmedDriveMode

        let trimmedNotes = notesText.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.notes = trimmedNotes.isEmpty ? nil : trimmedNotes

        resultStore.update(updated)
        onSave(updated)
        dismiss()
    }
}
