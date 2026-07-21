import SwiftUI

struct SettingsView: View {
    @AppStorage("accelSensitivity") private var accelSensitivity = 0.22
    @AppStorage("speedUnit") private var speedUnit: SpeedUnit = .kmh
    @AppStorage("appColorScheme") private var appColorScheme: AppColorScheme = .system
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .auto
    @State private var showDisclaimer = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Rechtliches") {
                    Button {
                        showDisclaimer = true
                    } label: {
                        Label("Hinweis zur StVO erneut anzeigen", systemImage: "exclamationmark.triangle")
                    }
                }

                Section("Sprache") {
                    Picker("Sprache", selection: $appLanguage) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.flagLabel).tag(language)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Einheit") {
                    Picker("Einheit", selection: $speedUnit) {
                        ForEach(SpeedUnit.allCases) { unit in
                            Text(unit.symbol).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Erscheinungsbild") {
                    Picker("Farbschema", selection: $appColorScheme) {
                        ForEach(AppColorScheme.allCases) { scheme in
                            Text(scheme.label).tag(scheme)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("G-Sensor Empfindlichkeit") {
                    Slider(value: $accelSensitivity, in: 0.10...0.40, step: 0.01) {
                        Text("Schwelle")
                    }
                    Text(String(format: String(localized: "Schwellwert: %.2f g", locale: appLanguage.resolvedLocale), accelSensitivity))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Niedriger = reagiert empfindlicher auf das Anfahren, kann aber durch Erschütterungen fehlauslösen. Höher = weniger anfällig, erkennt sanftes Anfahren u.U. später.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Section("Hinweise für genaue Messungen") {
                    Label("iPhone fest im Fahrzeug fixieren (Halterung).", systemImage: "iphone")
                    Label("Freie Sicht zum Himmel für guten GPS-Empfang.", systemImage: "antenna.radiowaves.left.and.right")
                    Label("Standort- und Bewegungszugriff erlauben.", systemImage: "location")
                }

                Section("Über die Messmethode") {
                    Text("Der Startzeitpunkt wird bei Messungen ab 0 km/h über den Beschleunigungssensor erkannt (bis zu 100 Messungen/Sekunde). Die Geschwindigkeit wird per GPS gemessen und zwischen den GPS-Updates über den Beschleunigungssensor interpoliert, um den exakten Zeitpunkt der Zielgeschwindigkeit präziser zu bestimmen.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Info") {
                    LabeledContent("Version", value: appVersion)
                }
            }
            .navigationTitle("Einstellungen")
            .sheet(isPresented: $showDisclaimer) {
                DisclaimerView()
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "–"
        return "\(version) (\(build))"
    }
}

#Preview {
    SettingsView()
}
