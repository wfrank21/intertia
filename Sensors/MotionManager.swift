import CoreMotion
import Foundation

/// Kapselt den Zugriff auf den Beschleunigungssensor (G-Sensor) über
/// CoreMotion. Liefert gravitationskompensierte Beschleunigungswerte
/// (`userAcceleration`, in g) mit hoher Abtastrate, die zum Erkennen des
/// Beschleunigungsbeginns sowie zur Interpolation zwischen GPS-Fixes
/// verwendet werden.
final class MotionManager {
    private let manager = CMMotionManager()
    private let updateQueue = OperationQueue()

    /// Wird bei jedem neuen Motion-Sample aufgerufen (Hauptthread).
    var onUpdate: ((CMDeviceMotion) -> Void)?

    var isAvailable: Bool {
        manager.isDeviceMotionAvailable
    }

    init() {
        updateQueue.name = "MotionManager.updateQueue"
        updateQueue.maxConcurrentOperationCount = 1
    }

    /// Startet die Messung mit 100 Hz. Höhere Rate = präziserer Start-Trigger
    /// und genauere Interpolation zwischen den (typischerweise 1 Hz) GPS-Fixes.
    func start() {
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 100.0
        manager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: updateQueue) { [weak self] motion, _ in
            guard let self, let motion else { return }
            DispatchQueue.main.async {
                self.onUpdate?(motion)
            }
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }
}
