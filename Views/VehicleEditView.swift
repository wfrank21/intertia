import SwiftUI

/// Formular zum Anlegen oder Bearbeiten eines Fahrzeugs. Wird sowohl für
/// "neues Fahrzeug hinzufügen" (`vehicle == nil`) als auch zum Bearbeiten
/// eines bestehenden Eintrags verwendet.
struct VehicleEditView: View {
    let vehicle: Vehicle?

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = VehicleStore.shared

    @State private var brand: String
    @State private var model: String
    @State private var yearText: String
    @State private var horsepowerText: String
    @State private var licensePlateText: String
    @State private var isDefault: Bool

    private var locale: Locale { AppLanguage.current.resolvedLocale }

    init(vehicle: Vehicle?) {
        self.vehicle = vehicle
        _brand = State(initialValue: vehicle?.brand ?? "")
        _model = State(initialValue: vehicle?.model ?? "")
        _yearText = State(initialValue: vehicle?.year.map(String.init) ?? "")
        _horsepowerText = State(initialValue: vehicle?.horsepowerPS.map(String.init) ?? "")
        _licensePlateText = State(initialValue: vehicle?.licensePlate ?? "")
        _isDefault = State(initialValue: vehicle?.isDefault ?? false)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Marke", text: $brand)
                    TextField("Modell", text: $model)
                }
                Section {
                    TextField("Baujahr", text: $yearText)
                        .keyboardType(.numberPad)
                    TextField("Leistung (PS)", text: $horsepowerText)
                        .keyboardType(.numberPad)
                    TextField("Kennzeichen", text: $licensePlateText)
                        .autocapitalization(.allCharacters)
                        .disableAutocorrection(true)
                }
                Section {
                    Toggle("Standardfahrzeug", isOn: $isDefault)
                }
                if vehicle != nil {
                    Section {
                        Button(role: .destructive) {
                            deleteAndDismiss()
                        } label: {
                            Text("Fahrzeug löschen")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .navigationTitle(vehicle == nil
                ? String(localized: "Fahrzeug hinzufügen", locale: locale)
                : String(localized: "Fahrzeug bearbeiten", locale: locale))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { save() }
                        .disabled(!isValid)
                }
            }
        }
    }

    private var isValid: Bool {
        !brand.trimmingCharacters(in: .whitespaces).isEmpty && !model.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func save() {
        var v = vehicle ?? Vehicle(brand: brand, model: model)
        v.brand = brand.trimmingCharacters(in: .whitespaces)
        v.model = model.trimmingCharacters(in: .whitespaces)
        v.year = Int(yearText)
        v.horsepowerPS = Int(horsepowerText)
        let trimmedPlate = licensePlateText.trimmingCharacters(in: .whitespaces)
        v.licensePlate = trimmedPlate.isEmpty ? nil : trimmedPlate
        v.isDefault = isDefault

        if vehicle == nil {
            store.add(v)
        } else {
            store.update(v)
        }
        dismiss()
    }

    private func deleteAndDismiss() {
        guard let vehicle, let idx = store.vehicles.firstIndex(where: { $0.id == vehicle.id }) else { return }
        store.delete(at: IndexSet(integer: idx))
        dismiss()
    }
}

#Preview {
    VehicleEditView(vehicle: nil)
}
