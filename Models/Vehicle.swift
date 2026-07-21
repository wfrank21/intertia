import Foundation

/// Ein vom Nutzer angelegtes Fahrzeug (z.B. das eigene Auto oder ein
/// Testfahrzeug), das optional einer Messung zugeordnet werden kann.
/// Genau ein Fahrzeug kann als Standard markiert sein (siehe
/// `VehicleStore.setDefault`) und wird dann automatisch für neue Messungen
/// vorausgewählt.
struct Vehicle: Identifiable, Codable, Equatable, Hashable {
    var id = UUID()
    var brand: String
    var model: String
    /// Baujahr, optional.
    var year: Int?
    /// Leistung in PS, optional.
    var horsepowerPS: Int?
    /// Amtliches Kennzeichen, optional (z.B. „M-AB 1234").
    var licensePlate: String?
    var isDefault: Bool = false

    /// Anzeigename, z.B. "BMW M3". Wird bei Messergebnissen zum
    /// Messzeitpunkt eingefroren (`MeasurementResult.vehicleDisplayName`),
    /// damit spätere Änderungen am Fahrzeug alte Ergebnisse nicht verändern.
    var displayName: String {
        "\(brand) \(model)"
    }
}
