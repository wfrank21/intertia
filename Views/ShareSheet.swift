import SwiftUI
import UIKit

/// Präsentiert UIKit's Share Sheet (`UIActivityViewController`) direkt über
/// den `rootViewController` des aktiven Fensters, statt über SwiftUIs
/// `.sheet(isPresented:)`. Grund: In der Kombination
/// `UIActivityViewController` (via `UIViewControllerRepresentable`) +
/// SwiftUI-`.sheet` bleibt der erste Aufruf zuverlässig nur ein leerer,
/// grauer Screen – ein bekannter Konflikt zwischen der SwiftUI-Sheet-
/// Transition und der eigenen Präsentationsanimation von
/// `UIActivityViewController` (erst ein zweites Antippen nach dem
/// Wegwischen funktioniert dann). Direktes Präsentieren über UIKit umgeht
/// das vollständig und ist außerdem der robusteste Weg über alle Ziel-
/// Konfigurationen hinweg (Nachrichten, Mail, AirDrop, „In Fotos sichern"
/// usw.), inkl. korrekter Popover-Positionierung auf dem iPad.
enum ShareSheetPresenter {
    static func present(items: [Any]) {
        guard
            let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive })
                ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
            let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first,
            let root = window.rootViewController
        else { return }

        var presenter = root
        while let presented = presenter.presentedViewController {
            presenter = presented
        }

        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(
                x: presenter.view.bounds.midX,
                y: presenter.view.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }
        presenter.present(activityVC, animated: true)
    }
}
