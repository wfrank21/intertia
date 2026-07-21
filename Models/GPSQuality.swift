import SwiftUI

/// Grobe Einstufung der GPS-Signalqualität anhand der horizontalen
/// Genauigkeit (`CLLocation.horizontalAccuracy`).
///
/// iOS stellt Apps die Anzahl erfasster Satelliten über keine öffentliche
/// API zur Verfügung (anders als z.B. Androids `GnssStatus`) – deshalb wird
/// die Signalqualität hier aus der Genauigkeit abgeleitet, die CoreLocation
/// ohnehin liefert.
enum GPSQuality: Int, CaseIterable, Comparable {
    case none = 0
    case poor = 1
    case fair = 2
    case good = 3
    case excellent = 4

    static func < (lhs: GPSQuality, rhs: GPSQuality) -> Bool { lhs.rawValue < rhs.rawValue }

    static func from(horizontalAccuracy: Double) -> GPSQuality {
        guard horizontalAccuracy >= 0 else { return .none }
        switch horizontalAccuracy {
        case ..<8: return .excellent
        case 8..<20: return .good
        case 20..<50: return .fair
        default: return .poor
        }
    }

    var label: LocalizedStringKey {
        switch self {
        case .none: return "Kein Signal"
        case .poor: return "Schwach"
        case .fair: return "Mittel"
        case .good: return "Gut"
        case .excellent: return "Ausgezeichnet"
        }
    }

    var color: Color {
        switch self {
        case .none: return .gray
        case .poor: return .red
        case .fair: return .orange
        case .good: return .yellow
        case .excellent: return .green
        }
    }
}
