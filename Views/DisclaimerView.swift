import SwiftUI

/// Rechtlicher Hinweis, der bei der ersten Nutzung akzeptiert werden muss und
/// jederzeit über die Einstellungen erneut aufrufbar ist.
///
/// - Bei Erstnutzung (`onAccept` gesetzt): Der Hinweis muss über die
///   Checkbox bestätigt werden, bevor die App nutzbar ist.
/// - Aus den Einstellungen aufgerufen (`onAccept` ist `nil`): Der Hinweis
///   wird nur informativ angezeigt und kann direkt geschlossen werden.
struct DisclaimerView: View {
    var onAccept: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var confirmed = false

    private var isFirstLaunch: Bool { onAccept != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.orange)
                        Text("Wichtiger Hinweis")
                            .font(.title2.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                    disclaimerSection(
                        title: "Straßenverkehrsordnung (StVO)",
                        text: "Inertia dient ausschließlich der privaten, informellen Messung von Beschleunigungs- und Bremswerten, z. B. auf privatem Gelände oder bei Veranstaltungen mit entsprechender Genehmigung. Bei jeder Nutzung im öffentlichen Straßenverkehr gelten uneingeschränkt die Vorschriften der Straßenverkehrsordnung (StVO) sowie alle weiteren geltenden Verkehrsvorschriften – insbesondere die zulässigen Höchstgeschwindigkeiten, das Rücksichtnahmegebot (§ 1 StVO) und sämtliche Vorfahrts- und Sicherheitsregeln. Diese App ist keine Aufforderung und keine Rechtfertigung, Geschwindigkeitsbegrenzungen zu überschreiten oder andere Verkehrsteilnehmer zu gefährden."
                    )

                    disclaimerSection(
                        title: "Keine Bedienung während der Fahrt",
                        text: "Gemäß § 23 Abs. 1a StVO ist die Nutzung eines Mobiltelefons während der Fahrt untersagt, wenn es dabei aufgenommen oder gehalten wird. Das iPhone muss während der Messung fest in einer Halterung montiert sein. Bedienung der App (Auswahl des Modus, Start, etc.) darf ausschließlich vor Fahrtantritt oder durch einen Beifahrer erfolgen – niemals durch die fahrende Person während der Fahrt."
                    )

                    disclaimerSection(
                        title: "Keine geeichte Messung",
                        text: "Die App nutzt die Sensoren deines iPhones (GPS und Beschleunigungssensor). Die ermittelten Werte sind Näherungswerte für private Zwecke und keine geeichten oder amtlich anerkannten Messergebnisse. Sie sind nicht für rechtliche, versicherungstechnische oder wettkampfoffizielle Zwecke geeignet."
                    )

                    disclaimerSection(
                        title: "Haftungsausschluss",
                        text: "Die Nutzung der App erfolgt auf eigene Verantwortung. Für Schäden, Bußgelder, Punkte in Flensburg oder sonstige Folgen, die aus der Nutzung der App oder aus Verkehrsverstößen entstehen, wird keine Haftung übernommen."
                    )

                    if isFirstLaunch {
                        Toggle(isOn: $confirmed) {
                            Text("Ich habe den Hinweis gelesen und verstanden und werde die StVO sowie alle geltenden Verkehrsvorschriften jederzeit einhalten.")
                                .font(.subheadline)
                        }
                        .padding(.top, 8)

                        Button {
                            onAccept?()
                        } label: {
                            Text("Verstanden & akzeptieren")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(!confirmed)
                        .padding(.top, 4)
                    }
                }
                .padding()
            }
            .navigationTitle("Rechtlicher Hinweis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isFirstLaunch {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Schließen") { dismiss() }
                    }
                }
            }
            .interactiveDismissDisabled(isFirstLaunch)
        }
    }

    private func disclaimerSection(title: String, text: String) -> some View {
        // `title`/`text` sind zur Laufzeit befüllte Strings, keine Literale –
        // Text(String) würde sie NICHT lokalisieren. Über LocalizedStringKey
        // erzwingen wir den Lookup im String Catalog trotzdem.
        VStack(alignment: .leading, spacing: 6) {
            Text(LocalizedStringKey(title))
                .font(.headline)
            Text(LocalizedStringKey(text))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview("Erstnutzung") {
    DisclaimerView(onAccept: {})
}

#Preview("Aus Einstellungen") {
    DisclaimerView()
}
