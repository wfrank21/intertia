import SwiftUI

struct ContentView: View {
    @AppStorage("hasAcceptedDisclaimer") private var hasAcceptedDisclaimer = false
    @AppStorage("appColorScheme") private var appColorScheme: AppColorScheme = .system
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .auto
    @State private var showDisclaimer = false

    var body: some View {
        TabView {
            MeasurementView()
                .tabItem { Label("Messung", systemImage: "speedometer") }

            HistoryView()
                .tabItem { Label("Verlauf", systemImage: "clock") }

            VehicleListView()
                .tabItem { Label("Fahrzeuge", systemImage: "car.fill") }

            SettingsView()
                .tabItem { Label("Einstellungen", systemImage: "gear") }
        }
        .environment(\.locale, appLanguage.resolvedLocale)
        .preferredColorScheme(appColorScheme.colorScheme)
        .onAppear {
            if !hasAcceptedDisclaimer {
                showDisclaimer = true
            }
        }
        .fullScreenCover(isPresented: $showDisclaimer) {
            DisclaimerView {
                hasAcceptedDisclaimer = true
                showDisclaimer = false
            }
        }
    }
}

#Preview {
    ContentView()
}
