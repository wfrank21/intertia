import Combine
import Foundation

/// Speichert die vom Nutzer angelegten Fahrzeuge als JSON im App-Sandbox-
/// Dokumentenverzeichnis, analog zu `ResultStore`.
final class VehicleStore: ObservableObject {
    static let shared = VehicleStore()

    @Published private(set) var vehicles: [Vehicle] = []

    private let fileURL: URL

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = docs.appendingPathComponent("vehicles.json")
        load()
    }

    /// Aktuell als Standard markiertes Fahrzeug, sofern vorhanden. Wird bei
    /// Messstart automatisch vorausgewählt (siehe `MeasurementView`).
    var defaultVehicle: Vehicle? {
        vehicles.first { $0.isDefault }
    }

    func add(_ vehicle: Vehicle) {
        var v = vehicle
        if vehicles.isEmpty {
            // Erstes angelegtes Fahrzeug wird automatisch zum Standard.
            v.isDefault = true
        }
        vehicles.append(v)
        if v.isDefault {
            unsetDefault(except: v.id)
        }
        persist()
    }

    func update(_ vehicle: Vehicle) {
        guard let idx = vehicles.firstIndex(where: { $0.id == vehicle.id }) else { return }
        vehicles[idx] = vehicle
        if vehicle.isDefault {
            unsetDefault(except: vehicle.id)
        }
        persist()
    }

    func delete(at offsets: IndexSet) {
        let removedWasDefault = offsets.contains { vehicles[$0].isDefault }
        vehicles.remove(atOffsets: offsets)
        if removedWasDefault, !vehicles.isEmpty {
            vehicles[0].isDefault = true
        }
        persist()
    }

    /// Markiert `vehicle` als Standard und alle anderen als nicht-Standard.
    func setDefault(_ vehicle: Vehicle) {
        for idx in vehicles.indices {
            vehicles[idx].isDefault = (vehicles[idx].id == vehicle.id)
        }
        persist()
    }

    private func unsetDefault(except id: UUID) {
        for idx in vehicles.indices where vehicles[idx].id != id {
            vehicles[idx].isDefault = false
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(vehicles)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("VehicleStore: Speichern fehlgeschlagen – \(error)")
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        if let decoded = try? JSONDecoder().decode([Vehicle].self, from: data) {
            vehicles = decoded
        }
    }
}
