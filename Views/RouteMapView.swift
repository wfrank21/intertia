import MapKit
import SwiftUI

/// Zeigt die gefahrene Strecke einer Messung als Linie auf einer Karte.
/// Nutzt bewusst `MKMapView` über `UIViewRepresentable` statt SwiftUIs
/// nativem `Map` mit `MapPolyline`, da Letzteres erst ab iOS 17 verfügbar
/// ist (Deployment Target dieser App: iOS 16).
struct RouteMapView: UIViewRepresentable {
    let coordinates: [CLLocationCoordinate2D]

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.pointOfInterestFilter = .excludingAll
        mapView.isRotateEnabled = false
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)

        guard coordinates.count >= 2 else { return }

        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        mapView.addOverlay(polyline)

        let startAnnotation = MKPointAnnotation()
        startAnnotation.coordinate = coordinates[0]
        startAnnotation.title = String(localized: "Start")
        mapView.addAnnotation(startAnnotation)

        let endAnnotation = MKPointAnnotation()
        endAnnotation.coordinate = coordinates[coordinates.count - 1]
        endAnnotation.title = String(localized: "Ziel")
        mapView.addAnnotation(endAnnotation)

        let padding = UIEdgeInsets(top: 28, left: 28, bottom: 28, right: 28)
        mapView.setVisibleMapRect(polyline.boundingMapRect, edgePadding: padding, animated: false)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .systemBlue
                renderer.lineWidth = 4
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard annotation is MKPointAnnotation else { return nil }
            let identifier = "RouteEndpoint"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view.annotation = annotation
            view.markerTintColor = annotation.title == String(localized: "Start") ? .systemGreen : .systemRed
            view.canShowCallout = true
            return view
        }
    }
}
