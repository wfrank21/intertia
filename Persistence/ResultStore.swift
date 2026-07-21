import Combine
import Foundation

/// Speichert vergangene Messergebnisse als JSON im App-Sandbox-
/// Dokumentenverzeichnis. Für den Funktionsumfang dieser App reicht ein
/// einfacher Datei-basierter Store; bei Bedarf lässt sich das später 1:1
/// gegen SwiftData/CoreData austauschen, ohne die Views anzupassen.
final class ResultStore: ObservableObject {
    static let shared = ResultStore()

    @Published private(set) var results: [MeasurementResult] = []

    private let fileURL: URL

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = docs.appendingPathComponent("results.json")
        load()
    }

    func save(_ result: MeasurementResult) {
        results.insert(result, at: 0)
        persist()
    }

    func delete(at offsets: IndexSet) {
        results.remove(atOffsets: offsets)
        persist()
    }

    /// Ersetzt ein bereits gespeichertes Ergebnis (gleiche `id`) durch die
    /// übergebene, geänderte Fassung – z.B. wenn Fahrzeug, Fahrmodus oder
    /// Notiz nachträglich über `ResultEditView` gesetzt wurden. Ändert
    /// nichts, wenn kein Ergebnis mit dieser `id` (mehr) existiert.
    func update(_ result: MeasurementResult) {
        guard let idx = results.firstIndex(where: { $0.id == result.id }) else { return }
        results[idx] = result
        persist()
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(results)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("ResultStore: Speichern fehlgeschlagen – \(error)")
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        if let decoded = try? JSONDecoder().decode([MeasurementResult].self, from: data) {
            results = decoded
        }
    }
}
