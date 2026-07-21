import Combine
import Foundation

/// Speichert vom Nutzer gesicherte, frei konfigurierte Messmodi
/// (`CustomModePreset`) als JSON im App-Sandbox-Dokumentenverzeichnis,
/// analog zu `ResultStore`/`VehicleStore`.
final class CustomModeStore: ObservableObject {
    static let shared = CustomModeStore()

    @Published private(set) var presets: [CustomModePreset] = []

    private let fileURL: URL

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = docs.appendingPathComponent("customModes.json")
        load()
    }

    func add(_ preset: CustomModePreset) {
        presets.append(preset)
        persist()
    }

    func delete(_ preset: CustomModePreset) {
        presets.removeAll { $0.id == preset.id }
        persist()
    }

    func delete(at offsets: IndexSet) {
        presets.remove(atOffsets: offsets)
        persist()
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(presets)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("CustomModeStore: Speichern fehlgeschlagen – \(error)")
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        if let decoded = try? JSONDecoder().decode([CustomModePreset].self, from: data) {
            presets = decoded
        }
    }
}
