import Combine
import CoreLocation
import Foundation

/// Kapselt CoreLocation und liefert die aktuelle GPS-Geschwindigkeit
/// (`CLLocation.speed`, in m/s) sowie die Positionsgenauigkeit. Für
/// Fahrzeugmessungen wird die höchste Genauigkeitsstufe und der Aktivitätstyp
/// `.automotiveNavigation` verwendet, damit iOS die GPS-/Sensor-Fusion des
/// Systems optimal auf Fahrsituationen abstimmt.
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentSpeedKmh: Double = 0
    @Published var horizontalAccuracy: Double = -1

    /// Wird bei jedem neuen Location-Update aufgerufen (Hauptthread).
    var onLocation: ((CLLocation) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.activityType = .automotiveNavigation
        manager.distanceFilter = kCLDistanceFilterNone
        authorizationStatus = manager.authorizationStatus
    }

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func start() {
        manager.startUpdatingLocation()
    }

    func stop() {
        manager.stopUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            start()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        horizontalAccuracy = location.horizontalAccuracy
        if location.speed >= 0 {
            currentSpeedKmh = location.speed * 3.6
        }
        onLocation?(location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // GPS-Fehler werden hier bewusst nicht hart behandelt – bei kurzem
        // Signalverlust läuft die Beschleunigungssensor-Interpolation weiter.
    }
}
